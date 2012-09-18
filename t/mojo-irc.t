use strict;
use warnings;
use Mojo::IRC;
use File::Slurp;
use Test::More;

plan tests => 6;
#$SIG{__DIE__} = \&Carp::cluck;

my $port = Mojo::IOLoop->generate_port;
my $read = '';

Mojo::IOLoop->server(
  port => $port,
  sub {
    my($self, $stream) = @_;
    my $data = read_file 't/data/irc.perl.org';
    $data =~ s/\n/\r\n/sg;
    $stream->on(read => sub { $read .= $_[1] });
    $stream->write($data);
  },
);

{
  my %got;
  my $irc = Mojo::IRC->new(
              nick => 'test123',
              user => 'my name',
              host => $ENV{IRC_HOST} || "localhost:$port",
            );

  $irc->on(join => sub {
    my($self, $message) = @_;

    is_deeply $message->{params}, ['#mojo'], 'got join #mojo event';
    is $message->{prefix}, 'test123!~my@1.2.3.4.foo.com', '...with prefix';
    is $got{rpl_motdstart}, 1, '1 motdstart event';
    is $got{rpl_motd}, 18, '18 motd events';
    is $got{rpl_endofmotd}, 1, '1 endofmotd event';
    is $read, "NICK test123\r\nUSER my name 8 * :WiRC IRC Proxy\r\nJOIN #mojo\r\n", 'nick, user and join got sent';
    Mojo::IOLoop->stop;
  });

  $irc->on(rpl_motdstart => sub { $got{rpl_motdstart}++ });
  $irc->on(rpl_motd => sub { $got{rpl_motd}++ });
  $irc->on(rpl_endofmotd => sub { $got{rpl_endofmotd}++ });

  $irc->connect(sub {
    my($irc, $err) = @_;
    return warn $err if $err;
    $irc->write(JOIN => '#mojo');
  });

  Mojo::IOLoop->start;
}