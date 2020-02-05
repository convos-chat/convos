use Test::More;
use Convos::Util qw(require_module short_checksum);
use Mojo::Util 'md5_sum';

is short_checksum(md5_sum(3)), '7Mvfktc4v4MZ8q68', 'short_checksum md5_sum';
is short_checksum('jhthorsen@cpan.org'), 'gGgA67dutavZz2t6', 'short_checksum email';
is short_checksum(md5_sum('jhthorsen@cpan.org')), 'gGgA67dutavZz2t6',
  'short_checksum md5_sum email';

eval { require_module 'Foo::Bar' };
my $err = $@;
like $err, qr{You need to install Foo::Bar to use main:}, 'require_module failed message';
like $err, qr{perl ./script/cpanm .* Foo::Bar},           'require_module failed cpanm';

eval { require_module 'Convos::Util' };
ok !$@, 'require_module success';

done_testing;
