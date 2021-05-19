use lib '.';
use t::Helper;
use Mojo::URL;
use Convos::Util 'pretty_connection_name';

is pretty_connection_name('irc://tyldum%40Convos%2Flibera:passw0rd@example.com:7000/'), 'libera',
  'ZNC style userinfo';

is pretty_connection_name('irc://user:passw0rd@example.com:7000/'), 'example', 'normal userinfo';
is pretty_connection_name('irc://example.com:7000/'),               'example', 'no userinfo';
is pretty_connection_name('irc://ssl.irc.perl.org/'),               'magnet',  'no userinfo';
is pretty_connection_name('ircs://irc.oftc.net:6697'),              'oftc',    'oftc';
is pretty_connection_name('irc.oftc.net'),             'oftc',        'oftc without scheme';
is pretty_connection_name('irc.darkscience.net:6697'), 'darkscience', 'darkscience';

done_testing;
