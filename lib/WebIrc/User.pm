package WebIrc::User;

=head1 NAME

WebIrc::User - Mojolicious controller for user data

=cut

use Mojo::Base 'Mojolicious::Controller';
use constant DEBUG => $ENV{WIRC_DEBUG} ? 1 : 0;

=head1 METHODS

=head2 auth

Check authentication and login

=cut

sub auth {
  my $self=shift;
  return 1 if $self->session('uid');
  $self->redirect_to('login');
  return 0;
}

=head2 login

Authenticate local user

=cut

sub login {
  my $self=shift;

  if($self->param('register')) {
    $self->stash(template => 'user/register');
    $self->register;
    return;
  }

  $self->render_later;
  $self->app->core->login(
    {
      login => scalar $self->param('login'),
      password => scalar $self->param('password'),
    },
    sub {
      my($core, $uid, $error) = @_;
      return $self->render(message => 'Invalid username/password.') unless $uid;
      $self->session(uid => $uid, login => $self->param('login'));
      $self->redirect_to('/settings');
    },
  );
}

=head2 register

See L</login>.

=cut

sub register {
  my $self=shift;
  my $admin=0;

  if($self->session('uid')) {
    $self->logf(debug => '[reg] Already logged in') if DEBUG;
    $self->redirect_to('/settings');
    return;
  }

  $self->render_later;
  Mojo::IOLoop->delay(sub {
    my $delay=shift;
    $self->redis->get('user:uids',$delay->begin);
  },
  sub { # Check invitation unless first user, or make admin.
    my ($delay,$uids)=@_;
    $self->logf(debug => '[reg] Got uids %s', $uids) if DEBUG;

    if($self->_got_invalid_register_params($uids)) {
      $self->logf(debug => '[reg] Failed %s', $self->stash('errors')) if DEBUG;
      $self->render;
      return;
    }

    if($uids) {
      $self->redis->get("user:@{[$self->param('login')]}:uid", $delay->begin);
    }
    else {
      $admin++;
      $self->logf(debug => '[reg] First login == admin') if DEBUG;
      $delay->begin->();
    }
  }, sub {  # Get uid unless user exists
    my ($delay,$uid)=@_;
    if($uid) {
      $self->stash('errors')->{login} = 'Username is taken.';
      $self->render;
    }
    else {
      $self->redis->incr('user:uids',$delay->begin);
    }
  }, sub { # Create user
    my ($delay,$uid)=@_;
    my $login = $self->param('login');
    my $digest = crypt $self->param('password'), join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    $self->logf(debug => '[reg] New user uid=%s, login=%s', $uid, $self->param('login')) if DEBUG;
    $self->session(uid=>$uid,login => $self->param('login'));
    $self->redis->execute(
      [ set => "user:$login:uid", $uid ],
      [ hmset => "user:$uid", digest => $digest, email => scalar $self->param('email') ],
      $delay->begin,
    );
  }, sub {
    my ($delay)=@_;
    $self->redirect_to('/settings');
  });
}

sub _got_invalid_register_params {
  my($self, $secret_required) = @_;
  my $errors = $self->stash('errors');
  my $email = $self->param('email') || '';
  my @passwords = $self->param('password');

  if($secret_required) {
    my $secret = $self->param('invite') || 'some-weird-secret-which-should-never-be-generated';
    $self->logf(debug => '[reg] Validating invite code %s', $secret) if DEBUG;
    if($secret ne crypt($email.$self->app->secret, $secret) && $secret ne 'OPEN SESAME') {
      $self->logf(debug => '[reg] Invalid invite code.') if DEBUG;
      $errors->{invite}='Invalid invite code.'
    }
  }

  if(($self->param('login') || '') !~ m/^[\w]{4,15}$/) {
    $errors->{login} = 'Username must consist of letters and numbers and be 4-15 characters long';
  }
  if($self->param('email') !~ m/.\@./) {
    $errors->{email} = 'Invalid email.';
  }

  if((grep { $_ } @passwords) != 2 or $passwords[0] ne $passwords[1]) {
    $errors->{password} = 'You need to enter the same password twice.';
  }
  elsif(length($passwords[0]) < 6) {
    $errors->{password} = 'The password must be at least 6 characters long';
  }

  return keys %$errors;
}

=head2 logout

Will delete data from session.

=cut

sub logout {
  my $self=shift;
  $self->session(uid=>undef,login=>undef);
  $self->redirect_to('/');
}

=head2 settings

Used to retrieve, save and update connection information.

=cut

sub settings {
  my $self = shift;
  my $uid = $self->session('uid');
  my $action = $self->param('action') || '';
  my(@actions, $cids, @connections, @clients);

  $self->stash(connections => \@connections);
  $self->stash(clients => \@clients);

  if($self->req->method eq 'POST') {
    push @actions, $action eq 'delete'        ? $self->_delete_connection
                 : $self->param('connection') ? $self->_update_connection
                 :                              $self->_add_connection;
  }
  if($action eq 'connect') {
    push @actions, sub {
      $self->redirect_to(view =>
        host => $self->param('host'),
        target => ($self->param('channels') =~ /(\S+)/)[0] || '',
      );
    };
  }

  my $last = sub {
    push @connections, { id => 0, %{ $self->app->config->{'default_connection'} }, nick => $self->session('login') };
    $self->param(connection => $connections[0]{id}) unless defined $self->param('connection');
    $self->render;
  };
  $self->render_later;
  Mojo::IOLoop->delay(
    @actions,
    sub { # get connections
      $self->redis->smembers("user:$uid:connections", $_[0]->begin);
    },
    sub { # get connection data
      $cids = $_[1];
      $self->logf(debug => '[settings] connections %s', $cids) if DEBUG;
      return $last->() unless $cids and @$cids;
      $self->redis->execute(
        (map { [ hgetall => "connection:$_" ] } @$cids),
        $_[0]->begin
      );
    },
    sub { # convert connections to data structures
      my $delay = shift;
      $self->logf(debug => '[settings] connection data %s', \@_) if DEBUG;
      for my $info (@_) {
        $info->{id} = shift @$cids;
        push @connections, $info;
      }
      $last->();
    },
  );
}

sub _add_connection {
  my $self = shift;

  sub {
   $self->app->core->add_connection($self->session('uid'), {
      host => $self->param('host') || '',
      nick => $self->param('nick') || '',
      user => $self->param('user') || $self->session('login'),
      channels => $self->param('channels') || '',
    }, $_[0]->begin);
  },
  sub {
    my ($delay,$cid,$cname)=@_;
    unless($cid) {
      $self->stash(errors => $cname); # cname is a hash-ref if $cid is undef
      $self->render;
      return;
    }
    $self->param(connection => $cid);
    $self->logf(debug => '[settings] cid=%s', $cid) if DEBUG;
    $self->app->core->start_connection($cid);
    $delay->begin->();
  },
}

sub _update_connection {
  my $self = shift;
  my $cid = $self->param('connection');
  # TODO: Should probably use some kind of $core->update_connection() to
  # actually update nick, user ++ as well

  $self->param(user => $self->session('login')) unless $self->param('user');

  sub {
    $self->logf(debug => '[settings] update %s', $cid) if DEBUG;
    $self->redis->execute(
      [ hmset => "connection:$cid", map { $_, scalar $self->param($_) } qw/ host user nick channels / ],
      $_[0]->begin,
    );
  },
}

sub _delete_connection {
  my $self = shift;
  my $uid = $self->session('uid');
  my $cid = $self->param('connection');

  $self->param(connection => 0);

  sub {
    $self->redis->srem("user:$uid:connections", $cid, $_[0]->begin);
  },
  sub {
    my($delay, $removed) = @_;
    return $_[0]->begin->() unless $removed;
    $self->redis->execute([ keys => "connection:$cid:*" ], $_[0]->begin);
  },
  sub {
    # TODO: Also disconnect from irc server in core
    my($delay, $keys) = @_;
    $self->redis->execute(
      [ del => @$keys ],
      [ srem => "connections", $cid ],
      $delay->begin,
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
