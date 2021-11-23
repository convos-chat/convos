package Convos::Controller::Files;
use Mojo::Base 'Mojolicious::Controller';

sub get {
  my $self = shift;
  my $user = $self->app->core->get_user_by_uid($self->stash('uid'));
  my $file = $self->_file(id => $self->stash('fid'), user => $user, types => $self->app->types);

  # Make sure we don't get 501 Not implemented if this is an API request
  $self->stash(handler => 'ep', openapi => 'Should never be rendered.');

  state $type_can_be_embedded = qr{^(application/javascript|application/json|image|text)};

  return $self->reply->not_found unless $file->user;    # invalid uid
  return $file->load_p->then(sub {
    return $self->reply->not_found unless eval { $file->filename };    # invalid fid
    return $self->reply->not_found if $file->write_only;

    my $ct = $file->mime_type;
    my $h  = $self->res->headers;
    $h->cache_control('max-age=86400');

    my $format = $self->stash('format') || '';
    return $self->render(file => file => $file) if !$format and $ct =~ m!$type_can_be_embedded!;

    $h->content_type($ct);
    $h->content_disposition(qq[attachment; filename="@{[$file->filename]}"])
      unless $ct =~ m!$type_can_be_embedded!;
    return $self->reply->asset($file->asset);
  });
}

sub upload {
  my $self = shift;

  # TODO: Move this to Mojolicious::Plugin::OpenAPI
  # Handle "Maximum message size exceeded"
  my $error = $self->req->error;
  $self->reply->errors([[$error->{message}, '/file']], 400) if $error;

  return unless $self->openapi->valid_input;
  return $self->reply->errors([], 401) unless my $user = $self->backend->user;

  my $upload = $self->req->upload('file');
  my $err;
  return $self->reply->errors([[$err, '/file']], 400)
    if $err = !$upload ? 'No upload.' : !$upload->filename ? 'Unknown filename.' : '';

  return $self->reply->errors([['SVG contains script.', '/file']], 400)
    if $upload->asset->contains('<script') != -1;

  my %meta = (filename => $upload->filename);
  $meta{id}         = $self->param('id')         if defined $self->param('id');
  $meta{write_only} = $self->param('write_only') if defined $self->param('write_only');

  my $asset = $upload->asset;
  $asset = $asset->to_file unless $asset->is_file;

  # The iPhone uploads every photo as "image.jpg"
  if ($meta{filename} =~ /^image.jpe?g$/i) {
    my $n = time % 10000;
    $meta{filename} = "IMG_$n.jpg";
  }

  return $self->_file(%meta, asset => $asset, user => $self->backend->user)
    ->save_p->then(sub { $self->render(openapi => {files => [shift]}) });
}

sub _file { shift->app->config('file_class')->new(@_) }

1;

=encoding utf8

=head1 NAME

Convos::Controller::Files - Convos file actions

=head1 DESCRIPTION

L<Convos::Controller::Files> is a L<Mojolicious::Controller> with
user files related actions.

=head1 METHODS

=head2 get

See L<https://convos.chat/api.html#op-get--file--uid--fid>.

=head2 upload

See L<https://convos.chat/api.html#op-post--file>.

=head1 SEE ALSO

L<Convos>.

=cut
