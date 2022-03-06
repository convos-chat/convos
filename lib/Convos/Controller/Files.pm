package Convos::Controller::Files;
use Mojo::Base 'Mojolicious::Controller', -async_await;

use Syntax::Keyword::Try;

async sub get {
  my $self = shift;
  my $user = $self->app->core->get_user_by_uid($self->stash('uid'));
  my $file = $self->_file(id => $self->stash('fid'), user => $user);

  # Make sure we don't get 501 Not implemented if this is an API request
  $self->stash(handler => 'ep', openapi => 'Should never be rendered.');

  state $type_can_be_embedded
    = qr{^(application/javascript|application/(json|xhtml|xml)|image|text)};
  state $type_can_be_viewed
    = qr{^(application/javascript|audio/|image/(gif|jpeg|png)|text/plain|video/)};

  return $self->reply->not_found unless $file->user;    # invalid uid
  await $file->load_p;

  return $self->reply->not_found unless eval { $file->filename };    # invalid fid
  return $self->reply->not_found if $file->write_only;

  my $ct = $file->mime_type;
  my $h  = $self->res->headers;
  $h->cache_control('max-age=86400');

  my $format = $self->stash('format') || '';
  return $self->render(file => file => $file) if !$format and $ct =~ m!$type_can_be_embedded!;

  $h->content_type($ct);
  $h->content_disposition(qq[attachment; filename="@{[$file->filename]}"])
    unless $ct =~ m!$type_can_be_viewed!;
  return $self->reply->asset($file->asset);
}

async sub list {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->reply->errors([], 401);

  my %params = map { ($_ => $self->param($_)) } qw(after before limit);
  my $files  = await $user->core->backend->files_p($user, \%params);
  $self->render(openapi => $files);
}

async sub remove {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->reply->errors([], 401);

  my @ids = split ',', $self->param('fid');
  return $self->render(openapi => {deleted => 0}) unless @ids;

  my ($backend, @errors) = ($user->core->backend);
  for my $id (@ids) {
    try {
      await $backend->delete_object_p($self->_file(id => $id, user => $user));
    }
    catch ($err) {
      push @errors, $err;
    }
  }

  return $self->render(openapi => {deleted => @ids - @errors});
}

async sub upload {
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

  my $file = await $self->_file(%meta, asset => $asset, user => $self->backend->user)->save_p;
  $self->render(openapi => {files => [$file]});
}

sub _file {
  my $self = shift;
  return $self->app->config('file_class')->new(log => $self->log, @_);
}

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

=head2 list

See L<https://convos.chat/api.html#op-get--files>.

=head2 remove

See L<https://convos.chat/api.html#op-post--delete-files>.

=head2 upload

See L<https://convos.chat/api.html#op-post--file>.

=head1 SEE ALSO

L<Convos>.

=cut
