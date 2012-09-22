use warnings;
use strict;
use Test::More;
use WebIrc::Core::Util qw/ pack_irc unpack_irc format_time /;

{
    my $time = 1348308427;
    my $str = pack_irc $time, ':test123!jhthorsen@m33p.com PRIVMSG #wirc :hey!';
    is_deeply(
        unpack_irc($str),
        {
            command => 'PRIVMSG',
            prefix => 'test123!jhthorsen@m33p.com',
            params => [ '#wirc', 'hey!' ],
            raw_line => ':test123!jhthorsen@m33p.com PRIVMSG #wirc :hey!',
            timestamp => 1348308427,
        },
        'managed to unpack packed IRC message',
    );
}

{
    my $time = 1348308427;
    is(
        format_time($time, '%d-%m-%y %n %w %H:%M:%S'),
        '22-09-2012 Sep Sat 12:07:07',
        'format_time(1348308427)'
    );
}

done_testing;
