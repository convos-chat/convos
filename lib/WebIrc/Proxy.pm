package WebIrc::Proxy;

use Mojo::Base -base;

has port => '6667';
has 'core';
has uid => undef;

sub start {
  my $self=shift;
  Mojo::IOLoop->server({ port => $self->port}, sub {
    my ($loop, $stream) = @_;
    $stream->timeout(15);
    my %credentials;
    $stream->on(read => sub {
      my ($stream, $chunk) = @_;
      my ($command,@args)=split m/\s+/,$chunk;
      if(!$self->uid) {
        if( $command ~~ m/^(?:PASS|USER|NICK)$/ ) {
          $credentials{$command}=$args[0];
        } else {
          warn $command;
          $stream->write(":wirc.pl NOTICE AUTH :*** REJECTED\r\n");
          return $stream->stop;
        }
        if($credentials{USER} && $credentials{PASS} && $credentials{NICK}) {
          $self->core->login(
            login=>$credentials{USER},
            password=>$credentials{PASSWORD},
            on_success => sub {
              $self->uid(shift);
              $stream->write(":wirc.pl NOTICE AUTH :*** AUTHENTICATED\r\n");
            },
            on_error => sub {
              $stream->write(":wirc.pl NOTICE AUTH :*** REJECTED\r\n");
              return $stream->stop;                
            }
          );
        }
      }     
    });
    $stream->write(":wirc.pl NOTICE AUTH :*** Welcome. Please enter credentials.\r\n"); 
  });
}

1;
