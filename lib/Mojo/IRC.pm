package Mojo::IRC;

1;

=head1 NAME

Mojo::IRC - IRC Client for the Mojo IOLoop

=head1 SYNOPSIS

my $irc=Mojo::IRC->new()

=head1 DESCRIPTION

=head1 METHODS

=head2 user

IRC username

=cut

has user => '';

=head2 host

IRC server hostname.

=cut

has host => '';
has _real_host => '';

=head2 password

IRC server password.

=cut

has password => '';

=head2 ssl

True if SSL should be used to connect to the IRC server.

=cut

has ssl => 0;

=head2 nick

IRC server nickname.

=cut

has nick => '';

=head2 channels

IRC channels to join on connect

=cut

=head1 COPYRIGHT

=cut