package Convos::Connection;

=head1 NAME

Convos::Connection - Mojolicious controller for IRC connections

=cut

use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

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

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
