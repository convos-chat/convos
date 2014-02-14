package Convos::Oembed;

=head1 NAME

Convos::Oembed - Generate oembed chunks.

=cut

use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 generate

Used to generate embed code to javascript.

=cut

sub generate {
  my $self    = shift->render_later;
  my $url     = $self->param('url');
  my $headers = $self->res->headers;

  #$header->etag(Mojo::Util::md5_sum($self->req->url->to_abs)); # not sure if this is a good idea
  $headers->cache_control('max-age=3600, must-revalidate');

  if ($url =~ /^http/) {
    $self->embed_link(
      $url => sub {
        my ($self, $link) = @_;
        my $embed_code = $link->to_embed;

        if ($embed_code =~ /^<a\s/) {    # do not want to embed links
          $self->render(layout => undef, text => '', status => 204);
        }
        else {
          $self->render(layout => 'oembed', text => $link->to_embed);
        }
      }
    );
  }
  else {
    return $self->render(text => '...', status => 400);
  }
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
