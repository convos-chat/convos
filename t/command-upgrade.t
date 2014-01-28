use Mojo::Base -strict;
use Test::More;

BEGIN {
  *Convos::Command::upgrade::kill  = sub {0};    # pretend kill
  *Convos::Command::upgrade::sleep = sub {0};    # pretend sleep
  require Convos::Command::upgrade;
}

my $cmd = Convos::Command::upgrade->new;
my (@redis_cmd, @redis_res);

$cmd->app(Mojo::Server->new->build_app('Convos'));

Mojo::Util::monkey_patch(
  'Mojo::Redis',
  'get' => sub {
    my ($redis, $key, $cb) = @_;
    $redis->$cb($$);
  }
);

Mojo::Util::monkey_patch(
  'Mojo::Redis',
  'execute' => sub {
    my ($redis, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : return;
    my $res = shift @redis_res || '';
    push @redis_cmd, @args;
    diag "@args => $res";
    $redis->$cb($res);
  }
);

{
  is $cmd->description, "Upgrade the Convos database.\n",            'description()';
  like $cmd->usage,     qr{BACKUP REDIS BEFORE RUNNING THE UPGRADE}, 'usage()';

  eval { $cmd->run };
  like $@, qr{BACKUP REDIS BEFORE RUNNING THE UPGRADE}, 'run()';

  is $cmd->run('--backup'), 1, 'failed --backup';
}

{
  @redis_cmd = ();
  @redis_res = (['dbfilename', 'foo.rdb'], 1, 1, 1);
  is $cmd->run('--backup'), 0, 'success --backup';
  is_deeply(
    \@redis_cmd,
    [
      qw(
        config get dbfilename
        config set dbfilename convos-backup.rdb
        save
        config set dbfilename foo.rdb
        )
    ],
    'redis commands on --backup',
  );
}

{
  @redis_cmd = ();
  @redis_res = qw( 1 1 );
  is $cmd->run('--yes'), 0, 'success --yes';
  is_deeply(
    \@redis_cmd,
    [
      qw(
        scard connections
        set convos:version 0.3005
        )
    ],
    'redis commands on --yes',
  );
}

{
  @redis_res = (['dbfilename', 'foo.rdb'], 1, 1, 1, 1, 1, 1);
  is $cmd->run(qw( --yes --backup )), 0, 'success --yes --backup';
}

done_testing;
