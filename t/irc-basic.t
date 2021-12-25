#!perl
use lib '.';
use t::Helper;
use Convos::Core;
use Convos::Core::Backend::File;

my $core       = Convos::Core->new(backend => 'Convos::Core::Backend::File');
my $user       = $core->user({email => 'test.user@example.com'});
my $connection = $user->connection({url => 'irc://127.0.0.1'});
my $settings_file
  = File::Spec->catfile($ENV{CONVOS_HOME}, qw(test.user@example.com irc-localhost connection.json));

subtest 'name and email' => sub {
  is $connection->name,        'localhost',             'connection.name';
  is $connection->user->email, 'test.user@example.com', 'user.email';
};

subtest 'persist' => sub {
  ok !-e $settings_file, 'no storage file';
  $connection->save_p->$wait_success('save_p');
  ok -e $settings_file, 'created storage file';
};

subtest TO_JSON => sub {
  cmp_deeply(
    $connection->TO_JSON,
    {
      connection_id       => ignore(),
      info                => {authenticated => false, capabilities => {}},
      name                => 'localhost',
      on_connect_commands => [],
      service_accounts    => [qw(chanserv nickserv)],
      state               => 'disconnected',
      url                 => 'irc://127.0.0.1',
      wanted_state        => 'connected',
    },
    'TO_JSON'
  );
};

subtest remove_connection_p => sub {
  is $connection->user, $user, 'user';
  ok -e $settings_file, 'settings_file exists before remove_connection()';
  $user->remove_connection_p($connection->id)->$wait_success('remove_connection_p');

  ok !-e $settings_file,                          'settings_file removed after remove_connection()';
  ok !-e File::Basename::dirname($settings_file), 'all files removed';
};

done_testing;
