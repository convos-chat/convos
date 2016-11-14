use lib '.';
use t::Helper;
use Convos;

my $convos = Convos->new;
my $home   = $INC{'Convos.pm'};
$home =~ s!\.pm$!!;

$convos->_home_relative_to_lib;
is $convos->home, $home, 'home';
is $convos->static->paths->[0], File::Spec->catdir($home, 'public'), 'static';

done_testing;
