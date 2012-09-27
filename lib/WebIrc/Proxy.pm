package WebIrc::Proxy;

use Mojo::Base -base;

has port => '6667';
has 'core';

sub start {
  my $self = shift;
  Mojo::IOLoop->server(
    {port => $self->port},
    sub {
      my ($loop, $stream) = @_;
      $stream->timeout(15);
      my %credentials;
      my $uid;
      $stream->on(
        read => sub {
          my ($stream, $chunk) = @_;
          my ($command, @args) = split m/\s+/, $chunk;
          if (!$uid) {
            if ($command ~~ m/^(?:PASS|USER|NICK)$/) {
              $credentials{$command} = $args[0];
            }
            else {
              $stream->write(":wirc.pl NOTICE AUTH :*** REJECTED\r\n");
              return $stream->stop;
            }
            if ($credentials{USER} && $credentials{NICK}) {
              if (!$credentials{PASS}) {
                $stream->write(
                  "wirc.pl AUTH :*** You need to send your password. Try /quote PASS <connection>:<password>\r\n"
                );
                return;
              }
              my ($pass,$cid)=split(':',$credentials{PASS});
              $self->core->login(
                {
                  login      => $credentials{USER},
                  password   => $pass,
                },
                sub {
                  my($core, $uid, $error) = @_;
                  if($uid) {
                    $stream->write(":wirc.pl NOTICE AUTH :*** AUTHENTICATED\r\n");
                    my @channels;
                    Mojo::IOLoop->delay(sub { 
                      my $delay=shift;
                      $core->redis->smembers("connection:$cid:channels", $delay->begin);
                      },
                      sub {
                        my $delay=shift;
                        @channels=@_;
                        foreach my $channel (@channels) {
                          $core->redis->get("connection:$cid:channel:$channel:topic",$delay->begin);
                        }
                      },
                      sub {
                        my ($delay,@topics)=@_;
                        for( my $i=0; $i++; $i<(scalar @channels) ) {
                          $stream->write(':wirc 332 '.$channels[$i].' :'.$topics[$i]);
                          $core->redis->smembers("connection:$cid:channel:".$channels[$i].":nicks",$delay->begin);                        
                        }
                      },
                      sub {
                        my ($delay, @members)=@_;
                        for( my $i=0; $i++; $i< (scalar @channels)) {
                          my @nicks=@{$members[$i]};
                          $stream->write(':wirc 353 '.$credentials{NICK}.' = '.$channels[$i].' :'.join(' ',@nicks));
                        }
                      }  
                    );
                  }
                  else {
                    $stream->write(":wirc.pl NOTICE AUTH :*** REJECTED\r\n");
                    $stream->stop;
                  }
                },
              );
            }
          }
          else {

          }
        }
      );
      $stream->write(
        ":wirc.pl NOTICE AUTH :*** Welcome. Please enter credentials.\r\n");
    }
  );
}

1;

=head1 NAME

WebIrc::Proxy - Proxy manager

=head1 SYNOPSIS

  my $proxy=WebIrc::Proxy->new(core=>$core);
  $proxy->start;

=head1 DESCRIPTION

L<WebIrc::Proxy> is responsible for dealing with native clients, allowing 
them to connect and communicate with the IRC servers.

=head2 ATTRIBUTES

=over 4

=item port

Port for the service to listen to. Defaults to 6667.

=item core

WebIrc Core class.

=back

=head2 METHODS

=over 4

=item start

Set up the listening port.

=back

=cut
