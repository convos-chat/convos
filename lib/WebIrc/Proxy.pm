package WebIrc::Proxy;

use Mojo::Base -base;

has port => '6667';
has 'core';

use Data::Dumper;

sub start {
  my ($self, $cb) = @_;
  Mojo::IOLoop->server(
    {port => $self->port},
    sub {
      my ($loop, $stream) = @_;
      $stream->timeout(15);
      my %credentials;
      my $uid;
      my $buffer = '';
      $stream->on(
        read => sub {
          my ($stream, $chunk) = @_;
          $buffer .= $chunk;
          while ($buffer =~ s/^([^\r\n]+)\r\n//m) {
            my ($command, @args) = split m/\s+/, $1;
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
                    "wirc.pl AUTH :*** You need to send your password. Try /quote PASS <connection>:<password>\r\n");
                  next;
                }
                my ($pass, $cid) = split(':', $credentials{PASS});
                $self->core->login(
                  {login => $credentials{USER}, password => $pass,},
                  sub {
                    my ($core,$uid) = @_;
                    if ($uid) {
                      $stream->write(":wirc.pl NOTICE AUTH :*** AUTHENTICATED\r\n");
                      my $channels;
                      Mojo::IOLoop->delay(
                        sub {
                          my $delay = shift;
                          $self->core->redis->smembers("connection:$uid:channels", $delay->begin);
                        },
                        sub {
                          my $delay = shift;
                          $channels = shift;
                          
                          foreach my $channel (@$channels) {
                            $self->core->redis->get("connection:$uid:channel:$channel:topic", $delay->begin);
                          }
                        },
                        sub {
                          my ($delay, @topics) = @_;
                          for (my $i = 0; $i < scalar @$channels; $i++) {
                            $stream->write(':wirc 332 ' . $channels->[$i] . ' :' . $topics[$i]."\r\n");
                            $self->core->redis->smembers("connection:$uid:names:" . $channels->[$i],
                              $delay->begin);
                          }
                        },
                        sub {
                          my ($delay, @members) = @_;
                          for (my $i = 0; $i < (scalar @$channels); $i++) {
                            my @nicks = @{$members[$i]};
                            $stream->write(
                              ':wirc 353 ' . $credentials{NICK} . ' = ' . $channels->[$i] . ' :' . join(' ', @nicks)."\r\n");
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
        }
      );
      $stream->write(":wirc.pl NOTICE AUTH :*** Welcome. Please enter credentials.\r\n");
    }
  );
  $cb->($self) if $cb;
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
