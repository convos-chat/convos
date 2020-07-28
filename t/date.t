use lib '.';
use t::Helper;
use Convos::Date 'dt';
use Mojo::JSON 'encode_json';
use Scalar::Util 'refaddr';

ok dt() >= time, 'now';

is '' . dt('784111777'),     '1994-11-06T08:49:37', 'epoch';
is '' . dt('784111777.001'), '1994-11-06T08:49:37', 'epoch decimal';

is '' . dt('1994-11-06T08:49:37'),      '1994-11-06T08:49:37', 'datetime';
is '' . dt('1994-11-06T08:49:37Z'),     '1994-11-06T08:49:37', 'datetime z';
is '' . dt('1994-11-06T08:49:37.001Z'), '1994-11-06T08:49:37', 'datetime decimal z';

is encode_json(dt('1994-11-06T08:49:37.001Z')), '"1994-11-06T08:49:37"', 'TO_JSON';

ok dt(784111777) > dt(784111770), 'gt';
ok dt(784111770) < dt(784111777), 'lt';
ok dt(784111770) == dt(784111770), 'eq';

my $dt = dt '784111777';
isnt refaddr(dt($dt)), refaddr($dt), 'dt returns new object';
is '' . dt($dt), '1994-11-06T08:49:37', 'dt dt and no wantarray';

done_testing;
