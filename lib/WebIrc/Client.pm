package WebIrc::Client;

=head1 NAME

WebIrc::Client - Mojolicious controller for IRC chat

=cut

use Mojo::Base 'Mojolicious::Controller';
use constant DEBUG => $ENV{WIRC_DEBUG} ? 1 : 0;

my $N_MESSAGES = 50;

=head1 METHODS

=head2 route

Route to last seen IRC channel.

=cut

sub route {
  my $self = shift->render_later;
  my $uid  = $self->session('uid');
  my $settings = sub { $self->redirect_to($self->url_for('settings')) };

  if(!$uid) {
    $self->render(template => 'index');
  }
  elsif($self->session('cid_target')) {
    my($cid, $target) = split /:/, $self->session('cid_target');
    $self->redirect_to(
      $self->url_for('channel.view', cid => $cid, target => $target)
    );
  }
  else {
    Mojo::IOLoop->delay(
      sub {
        my($delay) = @_;
        $self->redis->smembers("user:$uid:connections", $delay->begin);
      },
      sub {
        my($delay, $connections) = @_;
        return $settings->() unless $connections->[0];
        $self->redis->smembers("connection:$connections->[0]:channels", $delay->begin);
        $delay->begin->(undef, $connections->[0]);
      },
      sub {
        my($delay, $channels, $cid) = @_;
        $self->redirect_to(
          $self->url_for('channel.view', cid => $cid, target => $channels->[0])
        );
      }
    );
  }
}

=head2 view

Used to render the main IRC client view.

=cut

sub view {
  my $self   = shift->render_later;
  my $cid    = $self->param('cid');
  my $target = $self->param('target') || '';

  $self->session(cid_target => join ':', $cid, $target);

  Mojo::IOLoop->delay(
    $self->_check_if_uid_own_cid($cid),
    sub {
      my($delay, $cids) = @_;
      my $cb = $delay->begin;
      $self->redis->execute(
        (map { [ hmget => "connection:$_" => qw/ nick host / ] } @$cids),
        sub { $cb->(shift, [@_]) },
      );
      $delay->begin->(undef, $cids);
    },
    sub {
      my($delay, $connections, $cids) = @_;
      $self->_fetch_conversation_lists(
        $delay,
        map { +{ id => shift @$cids, host => $_->[1], nick => $_->[0] } } @$connections
      );
    },
    sub {
      my($delay, @connections) = @_;
      my($current) = grep { $_->{id} == $cid } @connections;

      $self->stash(
        connections => [ sort { $a->{host} cmp $b->{host} } @connections ],
        cid => $cid,
        target => $target,
        nick => $current->{nick} || '',
      );

      if($target) {
        $self->redis->smembers("connection:$cid:$target:nicks", $delay->begin);
      }
      else {
        $delay->begin->([]);
      }

      $self->_fetch_conversation($_[0], $cid, $target, 0);
    },
    sub {
      $self->stash(nicks => $_[1] || [], conversation => $_[2]);
      return $self->render(template => 'client/conversation', layout => undef) if $self->req->is_xhr;
      return $self->render;
    },

  );
}

=head2 history

Used to render the previous messages in a conversation, suitable for the IRC
client view.

=cut

sub history {
  my $self = shift->render_later;
  my $page = $self->stash('page');
  my $cid = $self->stash('cid');
  my $target = $self->stash('target') // '';

  unless($page and $cid) {
    return $self->render_exception('Missing parameters'); # TODO: Need to have a better error message?
  }

  Mojo::IOLoop->delay(
    $self->_check_if_uid_own_cid($cid),
    sub {
      $self->_fetch_conversation($_[0], $cid, $target, $page - 1);
    },
    sub {
      $self->render(
        cid => $cid,
        conversation => $_[1],
        layout => undef,
        nick => '',
        nicks => [],
        target => $target,
        template => 'client/conversation',
      );
    },
  );
}


sub _check_if_uid_own_cid {
  my($self, $cid) = @_;
  my $uid = $self->session('uid') // -1;

  sub {
    my($delay) = @_;
    $self->redis->sismember("user:$uid:connections", $cid, $delay->begin);
  },
  sub {
    my($delay, $is_owner) = @_;
    return $self->redis->smembers("user:$uid:connections", $delay->begin) if $is_owner;
    delete $self->session->{cid_target};
    return $self->route;
  },
}

sub _fetch_conversation {
  my($self, $delay, $cid, $target, $page) = @_;
  my $n_messages = 50;
  my $cb = $delay->begin;

  # FIXME: Should be using last seen tz and default to -inf
  $self->redis->zrevrangebyscore(
    $target ? "connection:$cid:$target:msg" : "connection:$cid:msg",
    "+inf" => "-inf",
    "withscores",
    "limit" => $page * $n_messages, $n_messages,
    sub { $cb->(undef, $self->format_conversation($_[1])) },
  );
}

sub _fetch_conversation_lists {
  my($self, $delay, @connections) = @_;

  for my $info (@connections) {
    my $cb = $delay->begin;
    $self->redis->execute(
      [ smembers => "connection:$info->{id}:channels" ],
      [ smembers => "connection:$info->{id}:conversations" ],
      sub {
        my ($redis, $channels, $conversations) = @_;
        $info->{channels} = $channels;
        $info->{conversations} = $conversations;
        $cb->(undef, $info);
      },
    );
  }
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
