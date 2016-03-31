package Convos::Controller::Url;
use Mojo::Base 'Mojolicious::Controller';

sub info {
  my $self = shift;
  my $url  = $self->param('url');

  if (!$self->backend->user) {
    return $self->stash(status => 401)
      ->respond_to(json => {json => {errors => []}}, any => {text => ''});
  }
  if (my $link = $self->app->_link_cache->get($url)) {
    $self->res->headers->header('X-Cached' => 1);    # for testing
    return $self->respond_to(json => {json => $link}, any => {text => $link->to_embed});
  }

  $self->delay(
    sub { $self->embed_link($self->param('url'), shift->begin) },
    sub {
      my $link = $_[1];
      $self->app->_link_cache->set($url => $link);
      $self->respond_to(json => {json => $link}, any => {text => $link->to_embed});
    },
  );
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Url - Expand URL to meta information

=head1 DESCRIPTION

L<Convos::Controller::Url> is a L<Mojolicious::Controller> that can retrieve
information about resources online.

=head1 METHODS

=head2 info

Used to expand a URL into markup, using L<Mojolicious::Plugin::LinkEmbedder>.

=head1 SEE ALSO

L<Convos>.

=cut
