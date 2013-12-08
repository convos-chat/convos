package Convos::Oembed;

=head1 NAME

Convos::Oembed - Generate oembed chunks.

=cut

use Mojo::Base 'Mojolicious::Controller';

has _ua => sub {
  # let's not spend too much time
  Mojo::UserAgent->new(request_timeout => 2, connect_timeout => 2);
};

=head1 METHODS

=head2 generate

Used to generate embed code to javascript.

=cut

sub generate {
  my $self = shift->render_later;
  my $url = $self->param('url');
  my $headers = $self->res->headers;

  #$header->etag(Mojo::Util::md5_sum($self->req->url->to_abs)); # not sure if this is a good idea
  $headers->cache_control('max-age=3600, must-revalidate');

  unless($url =~ /^http/) {
    return $self->render(text => '...', status => 400);
  }

  if($url =~ m!youtube.com\/watch?.*?\bv=([^&]+)!) {
    $self->render('oembed/youtube', width => 390, height => 220, id => $1);
  }
  else {
    $self->_ua->head(
      $url => sub {
        my $ct = $_[1]->res->headers->content_type || '';
        if($ct =~ /^image/) {
          $self->render('oembed/image', src => $url);
        }
        else {
          $self->render(text => $url, status => 404);
        }
      }
    );
  }
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
