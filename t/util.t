use Test::More;
use Convos::Util 'short_checksum';
use Mojo::Util 'md5_sum';

is short_checksum(md5_sum(3)), '7Mvfktc4v4MZ8q68', 'short_checksum md5_sum';
is short_checksum('jhthorsen@cpan.org'), 'gGg67dtvZz2t6VTw', 'short_checksum email';
is short_checksum(md5_sum('jhthorsen@cpan.org')), 'gGg67dtvZz2t6VTw',
  'short_checksum md5_sum email';

done_testing;
