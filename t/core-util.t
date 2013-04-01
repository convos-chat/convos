use warnings;
use strict;
use Test::More;
use WebIrc::Core::Util qw/ format_time /;

{
    my $time = 1348308427;
    is(
        format_time($time, '%d-%m-%y %n %w %H:%M:%S'),
        '22-09-2012 Sep Sat 12:07:07',
        'format_time(1348308427)'
    );
}

done_testing;
