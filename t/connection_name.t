use lib '.';
use t::Helper;
use Mojo::URL;
use Convos::Controller::Connection;

is name_for('irc://tyldum%40Convos%2Ffreenode:passw0rd@example.com:7000/'), 'freenode',
  'ZNC style userinfo';

is name_for('irc://user:passw0rd@example.com:7000/'), 'example', 'normal userinfo';
is name_for('irc://example.com:7000/'),               'example', 'no userinfo';
is name_for('irc://ssl.irc.perl.org/'),               'magnet',  'no userinfo';

done_testing;

sub name_for {
  Convos::Controller::Connection->_pretty_connection_name(Mojo::URL->new(shift));
}
