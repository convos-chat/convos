package Convos::Upgrader::v0_3003;

=head1 NAME

Convos::Upgrader::v0_3003 - Upgrade instructions to version 0.3003

=head1 DESCRIPTION

This upgrade step will add predefined networks to the database. These
networks are used to simplify the connection process.

=cut

use Mojo::Base 'Convos::Upgrader';

my %NETWORKS = (
  "efnet" =>
    {channels => '#efnet', home_page => "http://www.efnet.org", port => 6697, server => "irc.homelien.no", tls => 1,},
  "freenode" => {
    home_page => "http://www.freenode.net",
    channels  => '#perl',
    port      => 6697,
    server    => "chat.freenode.net",
    tls       => 1,
  },
  "magnet" => {
    channels  => '#convos',
    home_page => "http://www.irc.perl.org",
    port      => 6667,
    server    => "irc.perl.org",
    tls       => 0,
    default   => 1,
  },
);

=head1 METHODS

=head2 run

Called by L<Convos::Upgrader>.

=cut

sub run {
  my ($self, $cb) = @_;
  my $delay = $self->redis->ioloop->delay;
  my $guard = $delay->begin;

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->_add_predefined_networks($delay);
    },
    sub {
      my ($delay) = @_;
      $self->$cb('');
    },
  );
}

sub _add_predefined_networks {
  my ($self, $delay) = @_;
  my $redis = $self->redis;

  while (my ($name, $config) = each %NETWORKS) {
    $redis->set("irc:default:network", $name, $delay->begin) if delete $config->{default};
    $redis->sadd("irc:networks", $name, $delay->begin);
    $redis->hmset("irc:network:$name", $config, $delay->begin);
  }
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
