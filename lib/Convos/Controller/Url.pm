package Convos::Controller::Url;
use Mojo::Base 'Mojolicious::Controller', -async_await;

async sub check_for_updates {
  my $self = shift->openapi->valid_input or return;
  $self->backend->user                   or return $self->stash(status => 401);

  my $user_agent = $self->req->headers->user_agent;
  my $ua         = $self->linkembedder->ua;
  $ua->transactor->name($user_agent) if $user_agent;

  my $running   = $self->app->VERSION;
  my $tx        = await $ua->get_p('https://convos.chat/api', {'X-Convos-Version' => $running});
  my $json      = $tx->res->json;
  my $available = 0 + $json->{info}{version};
  $available = $running if $available < $running;

  return $self->render(openapi => {available => $available, running => $running});
}

sub err {
  my $self = shift;
  my $code = $self->stash('code') || '404';

  return $self->reply->not_found if $code eq '404';
  return $self->render('app', status => $code =~ m!^\d+$! ? $code : 200);
}

async sub info {
  my $self = shift->openapi->valid_input or return;
  my $url  = $self->param('url');

  if (!$self->backend->user) {
    return $self->stash(status => 401)
      ->respond_to(json => {json => {errors => []}}, any => {text => ''});
  }
  if (my $link = $self->_link_cache->get($url)) {
    $self->res->headers->header('X-Cached' => 1);    # for testing
    return $self->respond_to(json => {json => $link}, any => {text => $link->html});
  }

  # Some websites will not render complete pages without a proper User-Agent
  my $user_agent = $self->req->headers->user_agent;
  $self->linkembedder->ua->transactor->name($user_agent) if $user_agent;

  my $link = await $self->linkembedder->get_p($self->param('url'));
  if (my $err = $link->error) {
    $self->stash(status => $err->{code} || 500);
    $self->respond_to(
      json => {json => {errors => [$err]}},
      any  => {text => $err->{message} || 'Unknown error.'}
    );
    return;
  }

  $self->_link_cache->set($url => $link);
  $self->res->headers->cache_control('max-age=600');
  $self->respond_to(json => {json => $link}, any => {text => $link->html});
}

sub _link_cache {
  state $cache = Mojo::Cache->new->max_keys($ENV{CONVOS_MAX_LINK_CACHE_SIZE} || 100);
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Url - Expand URL to meta information

=head1 DESCRIPTION

L<Convos::Controller::Url> is a L<Mojolicious::Controller> that can retrieve
information about resources online.

=head1 METHODS

=head2 check_for_updates

Used to check if a newer version is available.

=head2 err

Render error/status pages.

=head2 info

Used to expand a URL into markup, using L<LinkEmbedder>.

=head1 SEE ALSO

L<Convos>.

=cut
