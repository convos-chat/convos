package Convos::Archive::ElasticSearch;

=head1 NAME

Convos::Archive::ElasticSearch - Archive to elastic search backend

=head1 DESCRIPTION

L<Convos::Archive::File> is a subclass of L<Convos::Archive> which use will
store the messages in L<Elasticsearch|http://www.elasticsearch.org>.

=cut

use Mojo::Base 'Convos::Archive';
use Mojo::UserAgent;

=head1 ATTRIBUTES

=head2 url

  $url = $self->url;

L<Mojo::URL> to Elasticsearch server. Default to L<http://localhost:9200>.

=cut

has url => sub { Mojo::URL->new('http://localhost:9200'); };

has _ua => sub { Mojo::UserAgent->new; };

=head1 METHODS

=head2 save

See L<Convos::Archive/save>.

=cut

sub save {
  my ($self, $conn, $message) = @_;
  my $url = $self->url->clone;

  $self->_ua->put($url->path(join '/', 'convos', 'irc_logs', $conn->login, $conn->name), json => $message, sub { });

  return $self;
}

=head1 COPYRIGHT

See L<Convos>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Marcus Ramberg - C<marcus@nordaaker.com>

=cut

1;
