package Convos::Connection;

=head1 NAME

Convos::Connection - Mojolicious controller for IRC connections

=cut

use Mojo::Base 'Mojolicious::Controller';
use Convos::Core::Util qw( as_id id_as );

=head1 METHODS

=head2 add_connection

Add a new connection based on network name.

=cut

sub add_connection {
  my $self = shift->render_later;
  my $validation = $self->validation;
  my $name = $self->param('name') || '';

  $validation->input->{channels} = [$self->param('channels')];
  $validation->input->{login} = $self->session('login');

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $self->redis->hgetall("irc:network:$name", $delay->begin);
    },
    sub {
      my($delay, $params) = @_;

      $validation->input->{$_} ||= $params->{$_} for keys %$params;
      $self->app->core->add_connection($validation, $delay->begin);
    },
    sub {
      my($delay, $errors, $conn) = @_;

      if($errors and $self->param('wizard')) {
        $self->stash(template => 'connection/wizard')->wizard;
      }
      elsif($errors) {
        $self->settings;
      }
      else {
        $self->redirect_to('view.network', network => 'convos');
      }
    },
  );
}

=head2 add_network

Add a new network.

NOTE: This method currently also does update.

=cut

sub add_network {
  my $self = shift->render_later;
  my $validation = $self->validation;
  my @channels = $self->param('channels');
  my($is_default, $name, $redis, $referrer);

  $self->stash(body_class => 'tactile', channels => \@channels);
  $self->req->method eq 'POST' or return $self->render;

  $validation->input->{tls} ||= 0;
  $validation->input->{password} ||= 0;
  $validation->required('name')->like(qr{^[-a-z0-9]+$});
  $validation->required('server')->like(qr{^[-a-z0-9_\.]+(:\d+)?$});
  $validation->required('password')->in(0, 1);
  $validation->required('tls')->in(0, 1);
  $validation->optional('home_page')->like(qr{^https?://.});
  $validation->has_error and return $self->render(status => 400);
  $validation->output->{channels} = join ' ', $self->param('channels');

  if($validation->output->{server} =~ s!:(\d+)!!) {
    $validation->output->{port} = $1;
  }
  else {
    $validation->output->{port} = $validation->input->{tls} ? 6697 : 6667;
  }

  $redis = $self->redis;
  $name = delete $validation->output->{name};
  $is_default = $self->param('default') || 0;
  $referrer = $self->param('referrer') || '/';

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;

      $redis->set("irc:default:network", $name, $delay->begin) if $is_default;
      $redis->sadd("irc:networks", $name, $delay->begin);
      $redis->hmset("irc:network:$name", $validation->output, $delay->begin);
    },
    sub {
      my($delay, @success) = @_;
      $self->redirect_to($referrer);
    },
  );
}

=head2 control

  /#host/control/start
  /#host/control/stop
  /#host/control/restart
  /#host/control/state

Used to control a connection. See L<Convos::Core/control>.

Special case is "state": It will return the state of the connection:
"disconnected", "error", "reconnecting" or "connected".

=cut

sub control {
  my $self = shift->render_later;
  my $command = $self->param('cmd') || 'state';

  if($command eq 'state') {
    $self->redis->hget(
      sprintf('user:%s:connection:%s', $self->session('login'), $self->stash('name')),
      'state',
      sub {
        my $redis = shift;
        my $state = shift || 'disconnected';

        $self->respond_to(
          json => { json => { state => $state } },
          any => { text => "$state\n" },
        );
      },
    );
  }
  elsif($self->req->method eq 'POST' and grep { $command eq $_ } qw( start stop restart )) {
    $self->app->core->control(
      $command,
      $self->session('login'),
      $self->stash('name'),
      sub {
        my($core, $sent) = @_;
        my $status = $sent ? 200 : 500;
        my $state = $command eq 'stop' ? 'stopping' : "${command}ing";

        $self->respond_to(
          json => { json => { state => $state }, status => $status },
          any => { text => "$state\n", status => $status },
        );
      },
    );
  }
  else {
    $self->respond_to(
      json => { json => {}, status => 400 },
      any => { text => "Invalid request\n", status => 400 },
    );
  }
}

=head2 edit_network

Used to edit settings for a network.

=cut

sub edit_network {
  my $self = shift->render_later;
  my $name = $self->stash('name');

  $self->stash(body_class => 'tactile');

  if($self->req->method eq 'POST') {
    $self->param(referrer => $self->req->url->to_abs);
    $self->validation->input->{name} = $name;
    $self->add_network;
    return;
  }

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;

      $self->redis->execute(
        [ get => 'irc:default:network' ],
        [ hgetall => "irc:network:$name" ],
        $delay->begin
      );
    },
    sub {
      my($delay, $default_network, $network) = @_;

      $network->{server} or return $self->render_not_found;
      $self->param($_ => $network->{$_} || '') for qw( password tls home_page );
      $self->param(name => $name);
      $self->param(default => 1) if $default_network eq $name;
      $self->param(server => join ':', @$network{qw( server port )});
      $self->render(
        channels => [ split /\s+/, $network->{channels} || '' ],
        default_network => $default_network,
        name => $name,
        network => $network,
      );
    },
  );
}

=head2 wizard

Used to add the first connection.

=cut

sub wizard {
  my $self = shift->render_later;
  my $redis = $self->redis;

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;

      $self->stash(body_class => 'tactile');
      $redis->smembers('irc:networks', $delay->begin);
    },
    sub {
      my $delay = shift;
      my @names = sort @{ shift || [] };

      @names = ('loopback') unless @names;
      $delay->begin(0)->(\@names);
      $redis->get('irc:default:network', $delay->begin);
      $redis->hgetall("irc:network:$_", $delay->begin) for @names;
    },
    sub {
      my($delay, $names, $default_network, @networks) = @_;
      my @channels;

      for my $network (@networks) {
        $network->{name} = shift @$names;
        @channels = split /\s+/, $network->{channels} || '' if $network->{name} eq $default_network;
      }

      $self->render(
        channels => \@channels,
        default_network => $default_network,
        networks => \@networks,
      );
    },
  );
}

=head2 edit_connection

Used to edit a connection.

=cut

sub edit_connection {
  my $self = shift->render_later;
  my $validation = $self->validation;

  $validation->input->{channels} = [$self->param('channels')];
  $validation->input->{login} = $self->session('login');
  $validation->input->{server} = $self->req->body_params->param('server');
  $validation->input->{tls} ||= 0;

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->update_connection($validation, $delay->begin);
    },
    sub {
      my ($delay, $errors, $changed) = @_;
      return $self->settings if $errors;
      return $self->redirect_to('view.network', network => 'convos');
    }
  );
}

=head2 delete_connection

Delete a connection.

=cut

sub delete_connection {
  my $self = shift->render_later;
  my $validation = $self->validation;

  $validation->input->{login} = $self->session('login');
  $validation->input->{name} = $self->stash('name');

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->app->core->delete_connection($validation, $delay->begin);
    },
    sub {
      my ($delay, $error) = @_;
      return $self->render_not_found if $error;
      return $self->redirect_to('view.network', network => 'convos');
    }
  );
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
