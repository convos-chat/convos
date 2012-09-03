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
                {
                  login      => $credentials{USER},
                  password   => $credentials{PASSWORD},
                },
                sub {
                  my($core, $uid, $error) = @_;
                  if($uid) {
                    $stream->write(":wirc.pl NOTICE AUTH :*** AUTHENTICATED\r\n");
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
