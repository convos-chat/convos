#!perl
use lib '.';
use t::Helper;

my $t_jane  = t::Helper->t;
my $t_joe   = t::Helper->t($t_jane->app);
my $t_robin = t::Helper->t($t_jane->app);

$t_jane->{nick}  = 'jane';
$t_joe->{nick}   = 'joe';
$t_robin->{nick} = 'robin';

note 'setup';
setup($_) for $t_jane, $t_joe;

note 'input check';
my %msg = (
  call_id       => 'aaaaaaaa-6f8b-44de-a0b1-4f09f544ee40',
  connection_id => 'irc-localhost',
  dialog_id     => '#convos',
  event         => 'signal',
  target        => 'joe',
);
$t_jane->send_ok({json => {method => 'rtc', %msg}})->message_ok->json_message_is('/event', 'rtc');

for my $key (qw(target dialog_id call_id event connection_id)) {
  delete $msg{$key};
  my $msg
    = $key eq 'dialog_id'     ? 'Dialog not found.'
    : $key eq 'connection_id' ? 'Connection not found.'
    :                           'Missing property.';

  $t_jane->send_ok({json => {method => 'rtc', %msg}})
    ->message_ok->json_message_is('/errors/0/message', $msg, $msg);
}

note 'jane signal joe';
$t_joe->message_ok->json_message_is('/call_id', 'aaaaaaaa-6f8b-44de-a0b1-4f09f544ee40')
  ->json_message_is('/connection_id', 'irc-localhost')->json_message_is('/dialog_id', '#convos')
  ->json_message_is('/from',          'jane')->json_message_is('/method', 'rtc')
  ->json_message_is('/target',        'joe')->json_message_is('/type', 'signal');

note 'robin joins';
setup($t_robin);

my %msg = (
  call_id       => 'cccccccc-6f8b-44de-a0b1-4f09f544ee40',
  connection_id => 'irc-localhost',
  dialog_id     => '#convos',
  event         => 'call',
);
$t_robin->send_ok({json => {method => 'rtc', %msg}})->message_ok->json_message_is('/event', 'rtc');

$msg{event} = 'bye';
$t_robin->send_ok({json => {method => 'rtc', %msg}})->message_ok->json_message_is('/event', 'rtc');

note 'robin signal jane and joe';
for my $t ($t_jane, $t_joe) {
  $t->message_ok->json_message_is('/call_id', 'cccccccc-6f8b-44de-a0b1-4f09f544ee40')
    ->json_message_is('/connection_id', 'irc-localhost')->json_message_is('/dialog_id', '#convos')
    ->json_message_is('/from',          'robin')->json_message_is('/method', 'rtc')
    ->json_message_is('/type',          'call');
  $t->message_ok->json_message_is('/call_id', 'cccccccc-6f8b-44de-a0b1-4f09f544ee40')
    ->json_message_is('/from', 'robin')->json_message_is('/type', 'bye');
}

done_testing;

sub setup {
  my $t    = shift;
  my $user = $t->app->core->user({email => "$t->{nick}\@example.com"})->set_password('s3cret');
  $user->save_p->$wait_success('save_p');

  $t->post_ok('/api/user/login', json => {email => "$t->{nick}\@example.com", password => 's3cret'})
    ->status_is(200);

  my $connection = $user->connection({name => 'localhost', protocol => 'irc'});
  $connection->state(connected => '');
  $connection->dialog({name => '#CONVOS', frozen => ''});

  $t->websocket_ok('/events');
}
