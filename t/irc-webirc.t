#!perl
BEGIN { $ENV{CONVOS_SKIP_CONNECT} = 1 }
use lib '.';
use t::Helper;
use t::Server::Irc;
use Convos::Core;
use Convos::Core::Backend::File;

my $server = t::Server::Irc->new->start;
my $core   = Convos::Core->new;
my $user   = $core->user({email => 'superwoman@example.com'});
$user->save_p->$wait_success;

my $connection = $user->connection({url => 'irc://example'});
$connection->save_p->$wait_success;

my @webirc;
$server->on(_irc_event_webirc => sub { push @webirc, pop });
$server->client($connection)->server_event_ok('_irc_event_cap')->server_event_ok('_irc_event_nick')
  ->server_write_ok(":example CAP * LS :\r\n")->client_event_ok('_irc_event_cap')
  ->server_write_ok(['welcome.irc'])->client_event_ok('_irc_event_rpl_welcome')
  ->process_ok('webirc is not sent');

$connection->disconnect_p->wait;

my $profile = $core->get_connection_profile('irc-example')->webirc_password('secret_passphrase');
is $connection->profile->id, $profile->id, 'shared profile id';
is $connection->profile->webirc_password, $profile->webirc_password,
  'shared profile webirc_password';

$server->client($connection)->server_event_ok('_irc_event_cap')->server_event_ok('_irc_event_nick')
  ->server_write_ok(":example CAP * LS :\r\n")->client_event_ok('_irc_event_cap')
  ->server_write_ok(['welcome.irc'])->client_event_ok('_irc_event_rpl_welcome')
  ->process_ok('webirc is sent');

is_deeply(
  [map { $_->{params} } @webirc],
  [[qw(secret_passphrase convos localhost 127.0.0.1)],],
  'webirc was sent once'
);

done_testing;
