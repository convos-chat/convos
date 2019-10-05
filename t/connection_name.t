use lib '.';
use t::Helper;
use Mojo::URL;
use Convos::Controller::Connection;

is (Convos::Controller::Connection::_pretty_connection_name(undef,Mojo::URL->new('irc://tyldum%40Convos%2Ffreenode:passw0rd@example.com:7000/')), 'freenode', 'ZNC style userinfo');
is (Convos::Controller::Connection::_pretty_connection_name(undef,Mojo::URL->new('irc://user:passw0rd@example.com:7000/')), 'example', 'normal userinfo');
is (Convos::Controller::Connection::_pretty_connection_name(undef,Mojo::URL->new('irc://example.com:7000/')), 'example', 'no userinfo');
is (Convos::Controller::Connection::_pretty_connection_name(undef,Mojo::URL->new('irc://ssl.irc.perl.org/')), 'magnet', 'no userinfo');

done_testing;
