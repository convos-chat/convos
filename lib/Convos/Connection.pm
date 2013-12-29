package Convos::Connection;

=head1 NAME

Convos::Connection - Mojolicious controller for IRC connections

=cut

use Mojo::Base 'Mojolicious::Controller';

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
        $self->redirect_to($self->param('wizard') ? 'convos' : 'settings');
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
  my($redis, $referrer, $name);

  $self->stash(body_class => 'tactile');
  $self->req->method eq 'POST' or return $self->render;

  $validation->input->{port} ||= $validation->input->{tls} ? 6697 : 6667;
  $validation->required('name')->like(qr{^[-a-z0-9]+$});
  $validation->required('port')->like(qr{^\d+$});
  $validation->required('server')->like(qr{^[-a-z0-9_\.]+$});
  $validation->required('tls')->in(0, 1);
  $validation->optional('home_page')->like(qr{^https?://.});
  $validation->has_error and return $self->render(status => 400);

  $redis = $self->redis;
  $name = delete $validation->output->{name};
  $referrer = $self->param('referrer') || '/';

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;

      $redis->sadd("irc:networks", $name, $delay->begin);
      $redis->hmset("irc:network:$name", $validation->output, $delay->begin);
    },
    sub {
      my($delay, @success) = @_;
      $self->redirect_to($referrer);
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
      my($delay, $names, $default, @networks) = @_;
      my @channels;

      for my $network (@networks) {
        $network->{name} = shift @$names;
        @channels = split /\s+/, $network->{channels} || '' if $network->{name} eq $default;
      }

      $self->render(
        channels => \@channels,
        default_network => $default,
        networks => \@networks
      );
    },
  );
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
