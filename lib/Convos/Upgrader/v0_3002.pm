package Convos::Upgrader::v0_3002;

=head1 NAME

Convos::Upgrader::v0_3002 - Upgrade instructions to version 0.3002

=head1 DESCRIPTION

This upgrade step will add predefined networks to the database. These
networks are used to simplify the connection process.

=cut

use Mojo::Base 'Convos::Upgrader';

my %NETWORKS = (
  "efnet" => {
    channels => '#efnet',
    home_page => "http://www.efnet.org",
    port => 6697,
    server => "irc.homelien.no",
    tls => 1,
  },
  "freenode" => {
    home_page => "http://www.freenode.net",
    channels => '#perl',
    port => 6697,
    server => "chat.freenode.net",
    tls => 1,
  },
  "magnet" => {
    channels => '#convos',
    home_page => "http://www.irc.perl.org",
    port => 7062,
    server => "irc.perl.org",
    tls => 1,
    default => 1,
  },
);

=head1 METHODS

=head2 run

Called by L<Convos::Upgrader>.

=cut

sub run {
  my $self = shift;
  my $delay = $self->redis->ioloop->delay;
  my $guard = $delay->begin;

  $self->_add_predefined_networks($delay);
  $delay->on(finish => sub { $self->emit('finish'); });
  $guard->(); # make sure finish is triggered
}

sub _add_predefined_networks {
  my($self, $delay) = @_;
  my $redis = $self->redis;

  while(my($name, $config) = each %NETWORKS) {
    $redis->set("irc:default:network", $name, $delay->begin) if delete $config->{default};
    $redis->sadd("irc:networks", $name, $delay->begin);
    $redis->hmset("irc:network:$name", $config, $delay->begin);
  }
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
