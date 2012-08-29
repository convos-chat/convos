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
                  "wirc.pl AUTH :*** You need to send your password. Try /quote PASS <username>:<password>\r\n"
                );
              }
              $self->core->login(
                login      => $credentials{USER},
                password   => $credentials{PASSWORD},
                on_success => sub {
                  $uid = shift;
                  $stream->write(
                    ":wirc.pl NOTICE AUTH :*** AUTHENTICATED\r\n");
                  $self->redis('')

                },
                on_error => sub {
                  $stream->write(":wirc.pl NOTICE AUTH :*** REJECTED\r\n");
                  return $stream->stop;
                }
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
