#!perl
use lib '.';
use t::Helper;
use Convos::Core;

plan skip_all => 'TEST_NETWORKS=all is not set' unless $ENV{TEST_NETWORKS};

my $core = Convos::Core->new;
my $user = $core->user({email => 'jhthorsen@cpan.org'});

my %hosts = (
  'chicago.il.us.undernet.org'  => {tls => 0},
  'efnet.port80.se:6697'        => {tls => 1},
  'eris.us.ircnet.net'          => {tls => 0},
  'irc.irchighway.net:6697'     => {tls => 1},
  'irc.perl.org'                => {tls => 0},
  'irc.snoonet.org:6697'        => {tls => 1},
  'underworld1.no.quakenet.org' => {tls => 0},
);

# Just test one server: TEST_NETWORKS=snoonet prove -vl t/real-irc-servers.t
unless ($ENV{TEST_NETWORKS} eq 'all') {
  my $filter = $ENV{TEST_NETWORKS};
  delete $hosts{$_} for grep {/^(irc\.)?$filter/} keys %hosts;
}

for my $host (sort keys %hosts) {
  my ($err, $name) = ('err was not set', $host);
  $name =~ s!:\d+$!!;
  $name =~ s!\W!-!g;
  my $connection = $user->connection({url => "irc://$name"});
  $connection->url->parse("irc://$host");
  $connection->connect(sub { connected($host, @_) });
  note "connecting to $host ...";
}

Mojo::IOLoop->start;
done_testing;

sub connected {
  my ($host, $connection, $err) = @_;
  my $expected = delete $hosts{$host};
  my $got      = {
    err   => $err // '',
    state => $connection->state,
    tls   => ($connection->url->query->param('tls') // 1) ? 1 : 0,
  };

  @{$expected}{qw(err state)} = ('', 'connected');
  is_deeply($got, $expected, "connected to $host") or diag Mojo::Util::dumper([$got, $expected]);

  Mojo::IOLoop->stop unless keys %hosts;
}
