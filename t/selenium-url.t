use lib '.';
use t::Selenium;

my $t = t::Selenium->selenium_init('Convos');
my $url;

$t->navigate_ok('/?_vue=false&x=2');

$url = $t->driver->execute_script('return new Url()');
like $url->{protocol}, qr{^https?$}, 'location.href protocol';
like $url->{host},     qr{\w},       'location.href host';
like $url->{port},     qr{^\d+$},    'location.href port';
is_deeply $url->{path}, [], 'location.href path';
is $url->{fragment}, '', 'location.href fragment';
is_deeply $url->{query}, {_vue => ['false'], x => [2]}, 'location.href query';

$url
  = $t->driver->execute_script('return new Url("irc://wonderwoman:secret@irc.example.com:6667")');
is $url->{protocol}, 'irc',             'irc protocol';
is $url->{user},     'wonderwoman',     'irc user';
is $url->{pass},     'secret',          'irc pass';
is $url->{host},     'irc.example.com', 'irc host';
is $url->{port},     '6667',            'irc port';
is_deeply $url->{path}, [], 'irc path';
is $url->{fragment}, '', 'irc fragment';
is_deeply $url->{query}, {}, 'irc query';

$url = $t->driver->execute_script('return new Url("//whatever@example.com/p1//p3#target")');
is $url->{protocol}, '',            'without protocol protocol';
is $url->{user},     'whatever',    'without protocol user';
is $url->{pass},     '',            'without protocol pass';
is $url->{host},     'example.com', 'without protocol host';
is $url->{port},     '',            'without protocol port';
is_deeply $url->{path}, ['p1', '', 'p3'], 'without protocol path';
is $url->{fragment}, 'target', 'without protocol fragment';
is_deeply $url->{query}, {}, 'without protocol query';

$url = $t->driver->execute_script('return new Url("wss://:secret@localhost?foo=1#target")');
is $url->{protocol}, 'wss',       'wss protocol';
is $url->{user},     '',          'wss user';
is $url->{pass},     'secret',    'wss pass';
is $url->{host},     'localhost', 'wss host';
is $url->{port},     '',          'wss port';
is_deeply $url->{path}, [], 'wss path';
is $url->{fragment}, 'target', 'wss fragment';
is_deeply $url->{query}, {foo => ['1']}, 'wss query';

$url = $t->driver->execute_script('return new Url("//0.0.0.0")');
is $url->{protocol}, '',    'special protocol';
is $url->{user},     undef, 'special user';
is $url->{pass},     undef, 'special pass';
is $url->{host},     '',    'special host';
is $url->{port},     '',    'special port';
is $t->driver->execute_script('return new Url("//0.0.0.0").toString()'), '', 'special toString';

for my $url (
  'http://127.0.0.1',
  'http://[::1]:9999',
  'https://wonderwoman:example@example.com:8080/x/index.html?_x=1&y=2#/!%?@3',
  'wss://:secret@localhost?foo=1#target',
  'irc://wonderwoman:secret@irc.example.com:6667',
  'irc://:secret@irc.example.com:6667',
  'irc://:secret@irc.example.com:6667?nick=wonderwoman&tls=1',
  '//localhost',
  '//whatever@example.com/p1//p3#target',
  )
{
  is $t->driver->execute_script(qq[return new Url("$url").toString()]), $url, "toString $url";
}

#$t->browser_log;
#die Data::Dumper::Dumper($url);

done_testing;
