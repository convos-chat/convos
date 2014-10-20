#!/usr/bin/env perl
BEGIN {
  $ENV{CONVOS_BACKEND_ONLY} = 1;    # less initialization on startup
  $ENV{CONVOS_REDIS_URL} ||= 'localhost';
  $ENV{MOJO_REDIS_DEBUG} //= 0;
}

use Mojo::Base -strict;
use Mojo::JSON 'j';
use lib 'lib';
use Convos;
use Convos::Core::Connection;

my ($login, $event, $data) = @ARGV;
my $convos = Convos->new;
my $redis  = $convos->redis;
my $c;

$login and $event or die usage();
$data = j $data || '{}';

$c = Convos::Core::Connection->new(name => $data->{network} || 'magnet', login => $login, redis => $redis);
$redis->on(message => "convos:user:$login:out" => \&message);
$c->_publish($event, {data($event), %$data});
Mojo::IOLoop->start;

sub data {
  return (
      $_[0] eq 'add_conversation' ? (target => '#foo')
    : $_[0] eq 'go_forward_in_history' ? (target => '#convos', conversation => [{timestamp => time}])
    : $_[0] eq 'remove_conversation' ? (target => '#foo')
    : $_[0] eq 'mode' ? (target => '#foo', mode => '+o', args => 'TODO')
    : $_[0] eq 'nick_change' ? (old_nick => 'bbb',     new_nick => 'testwoman')
    : $_[0] eq 'nick_joined' ? (nick     => 'testman', target   => '#foo')
    : $_[0] eq 'nick_parted' ? (nick     => 'testman', target   => '#foo')
    : $_[0] eq 'rpl_namreply'
    ? (nicks => [{nick => 'testman', mode => 'o'}, {nick => 'bbb', mode => '+'}], target => '#foo')
    : $_[0] eq 'nick_quit'      ? (nick   => 'testwoman',       message => 'Bye, bye love')
    : $_[0] eq 'server_message' ? (status => 200,               message => 'Some message')
    : $_[0] eq 'topic'          ? (topic  => 'Too cool topic!', target  => '#foo')
    : $_[0] eq 'whois'          ? (
      target   => '#foo',
      channels => ['#mojo'],
      idle     => 10,
      realname => 'Bruce Wayne',
      user     => '~todo@127.0.0.1',
      nick     => 'batman'
      )
    : ()
  );
}

sub message {
  my ($redis, $err, $message, $channel) = @_;
  warn "\nMessage sent to $channel.\n\n";
  print $message, "\n";
  warn "\n";
  Mojo::IOLoop->stop;
}

sub usage {
  die <<"USAGE";

Usage: $0 <login> <event> <data>

Examples with default data:
  $0 jhthorsen add_conversation
  $0 jhthorsen remove_conversation
  $0 jhthorsen mode
  $0 jhthorsen nick_change
  $0 jhthorsen nick_joined
  $0 jhthorsen nick_parted
  $0 jhthorsen nick_quit
  $0 jhthorsen rpl_namreply
  $0 jhthorsen server_message
  $0 jhthorsen topic
  $0 jhthorsen whois

With data (Input keys will overwrite the defaults)
  $0 jhthorsen nick_joined '{"nick":"some_nick","target":"#test"}'

USAGE
}
