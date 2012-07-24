package WebIrc::Core::Connection;

use Mojo::Base -base;
use Net::Async::IRC;
use IO::Async::Loop::Mojo;


has 'redis';
has 'irc' => sub {
  my $loop = IO::Async::Loop::Mojo->new();
  my $irc=Net::Async::IRC->new(on_message_text=>sub {
      my ($this,$message,$hints)=@_;
    });
  $loop->add($irc);
  return $irc;
};

# Stored config
has 'id';
has 'user';
has 'host';
has 'port';
has 'password';
has 'ssl' => sub { 0 };
has 'nick';

has 'stream';

my @keys=qw/user host port password ssl/;

sub load {
  my ($self,$id,$cb)=@_;
  my $delay;
  if(!$cb) {
    $delay=Mojo::IOLoop->delay;
    $delay->start;
  }
  $self->id($id);
  $self->redis->mget([ map { "connection:$id:$_" } @keys], sub {
    my ($redis,$res)=@_;
    foreach my $key (@keys) {
      $self->$key(pop @$res);
    }
    if ($delay) {
      $delay->end;
    } else {
      $cb->($self);
    }
  });
  return $self;
}

sub connect {
  my $self=shift;
  return if $self->irc->is_loggedin;
  $self->irc->login(
    nick      => $self->nick,
    host      => $self->host,
    service   => ( $self->port || 6667 ),
    pass      => $self->password,
    on_login  => sub {
      my $irc=shift;
      $irc->join()
    },
    on_error  => sub {
      my ($msg) =@_;
    # FIXME: handle errors here
  });
}

sub disconnect {
  my $self = shift;
  $self->stream->write('QUIT');
  $self->stream->close;
}

1;