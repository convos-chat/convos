use strict;
use warnings;
use Mojo::IRC;
use File::Slurp;
use Test::More;

plan tests => 9;
#$SIG{__DIE__} = \&Carp::cluck;

my $port = Mojo::IOLoop->generate_port;
my $read = '';

Mojo::IOLoop->server(
  {port => $port},
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
  my $irc = Mojo::IRC->new();
  isa_ok($irc,'Mojo::IRC','Constructor returns right object');
  $irc->nick('test123');
  is($irc->nick(),'test123','nick setter works');
  $irc->user('my name');
  my $server=$ENV{IRC_HOST} || "localhost:$port";
  $irc->server($server);
  is($irc->server(),$server,'server setter works');

  $irc->on(irc_join => sub {
    my($self, $message) = @_;

    is_deeply $message->{params}, ['#mojo'], 'got join #mojo event';
    is $message->{prefix}, 'test123!~my@1.2.3.4.foo.com', '...with prefix';
    is $got{rpl_motdstart}, 1, '1 motdstart event';
    is $got{rpl_motd}, 18, '18 motd events';
    is $got{rpl_endofmotd}, 1, '1 endofmotd event';
    is $read, "NICK test123\r\nUSER my name 8 * :Mojo IRC\r\nJOIN #mojo\r\n", 'nick, user and join got sent';
    Mojo::IOLoop->stop;
  });

  $irc->on(irc_rpl_motdstart => sub { $got{rpl_motdstart}++ });
  $irc->on(irc_rpl_motd => sub { $got{rpl_motd}++ });
  $irc->on(irc_rpl_endofmotd => sub { $got{rpl_endofmotd}++ });

  $irc->connect(sub {
    my($irc, $err) = @_;
    return warn $err if $err;
    $irc->write(JOIN => '#mojo');
  });

  Mojo::IOLoop->start;
}
  