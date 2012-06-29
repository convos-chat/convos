package WebIrc::Core::Connection;

use Mojo::Base -base;

has 'redis';

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
  Mojo::IOLoop->client({

    })
}

sub disconnect {
  my $self = shift;
  $self->stream->write('QUIT');
  $self->stream->close;
}

1;