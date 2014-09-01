use t::Helper;
use Convos::Core;

my $core = $t->app->core;
my $sub  = $core->redis->subscribe(qw( convos:user:batman:magnet ));
my $stop = sub {1};
my (@messages, @res);

$core->start(sub { Mojo::IOLoop->stop; });
Mojo::IOLoop->start;

{
  no warnings 'redefine';
  *Mojo::IRC::connect = sub { Mojo::IOLoop->stop; };

  $sub->on(
    message => sub {
      my ($sub, $message, $channel) = @_;
      push @messages, $message;
      local $_ = $message;
      Mojo::IOLoop->stop if $stop->();
    }
  );
}

# add_connection() ===========================================================

{
  my $conn = {};
  $core->add_connection($conn, cb());
  Mojo::IOLoop->start;
  is $res[2], undef, 'add_connection() failed on invalid input';
  is_deeply $res[1]->error('name'), ['required'], 'name (and friends) failed';
}

{
  my $conn = {password => 's3cret', login => 'batman', name => 'magnet', nick => 'batman', server => 'irc.perl.org',};

  $core->add_connection($conn, cb());
  Mojo::IOLoop->start;
  is $res[1], undef, 'add_connection() magnet';    # or diag Data::Dumper::Dumper($res[1]->{error});
  $conn->{nick} = 'batman';
  is_deeply $res[2], $conn, 'add_connection() returned connection details';

  Mojo::IOLoop->start;
  is $core->{connections}{batman}{magnet}->_irc->nick,   'batman',       'irc nick';
  is $core->{connections}{batman}{magnet}->_irc->server, 'irc.perl.org', 'irc server';
  is $core->{connections}{batman}{magnet}->_irc->user,   'batman',       'irc user';

  $core->add_connection($conn, cb());
  Mojo::IOLoop->start;
  is_deeply $res[1]->error('name'), ['exists'], 'connection exists';
}

# update_connection() ========================================================

{
  my $conn = {};
  $core->update_connection($conn, cb());
  Mojo::IOLoop->start;
  is $res[2], undef, 'update_connection() failed on invalid input';
  is_deeply $res[1]->error('name'), ['required'], 'name (and friends) failed';
}

{
  my $conn = {login => 'batman', name => 'magnet', nick => 'bruce', server => 'irc.perl.org'};

  @messages = ();
  $stop = sub {/NICK bruce/};
  $core->update_connection($conn, cb());
  Mojo::IOLoop->start;
  is $res[1], undef, 'update_connection(normal) magnet' or diag Data::Dumper::Dumper($res[1]->{error});
  is_deeply $res[2], $conn, 'update_connection(normal) returned connection details';

  Mojo::IOLoop->start unless @messages == 3;
  is_deeply \@messages, ['dummy-uuid NICK bruce'], 'sent NICK + JOIN + PART';
}

{
  my $conn = {login => 'batman', name => 'magnet', nick => 'bruce', server => 'irc.perl.org:1234'};

  $core->update_connection($conn, cb());
  Mojo::IOLoop->start;
  is $res[1], undef, 'update_connection(change) change server' or diag Data::Dumper::Dumper($res[1]->{error});
  is_deeply $res[2], $conn, 'update_connection(change) returned connection details';

  Mojo::IOLoop->start;
  is $core->{connections}{batman}{magnet}->_irc->nick,   'bruce',             'irc nick bruce';
  is $core->{connections}{batman}{magnet}->_irc->server, 'irc.perl.org:1234', 'irc server irc.perl.org:1234';
  is $core->{connections}{batman}{magnet}->_irc->user,   'batman',            'irc user batman';
}

done_testing;

sub cb {
  my $tid = Mojo::IOLoop->timer(1 => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->timer(0 => sub { @res and Mojo::IOLoop->stop });
  @res = ();

  sub {
    @res = @_;
    Mojo::IOLoop->remove($tid);
    Mojo::IOLoop->stop;
  };
}
