use lib '.';
use t::Helper;
use Mojo::File 'tempfile';

my $tmp = tempfile;
$ENV{CONVOS_LOG_FILE} = "$tmp";
diag "CONVOS_LOG_FILE=$ENV{CONVOS_LOG_FILE}";
$$tmp->close;
my $convos = Convos->new;

is $convos->config->{log_file}, "$tmp", "log_file";
$convos->log->error("this is a really cool log message");
like $tmp->slurp, qr{this is a really cool log message}, 'log file content';

done_testing;
