package Convos::Plugin::Files;
use Mojo::Base 'Convos::Plugin';

use Convos::Plugin::Files::File;

sub register {
  my ($self, $app, $config) = @_;

  $app->helper('files.serve'  => \&_serve);
  $app->helper('files.save_p' => \&_save_p);

  # Friendly alias for /api/file/:uid/:fid
  $app->routes->get('/file/:uid/:fid', [format => 1])->to('files#get');

  # Upgrade message to paste
  $app->core->backend->on(message_to_paste => 'Convos::Plugin::Files::File');

  # Back compat from Convos::Plugin::Paste
  $app->routes->get('/paste/:email_hash/:file_hash', [format => 1], \&_back_compat);
}

sub _back_compat {
  my $c = shift;

  my $email_hash = $c->stash('email_hash');
  my $user;
  for my $u (@{$c->app->core->users}) {
    $user = $u and last if index(Mojo::Util::sha1_sum($u->email), $email_hash) == 0;
  }

  return $c->reply->not_found unless $user;    # invalid email_hash
  return _serve($c,
    {fid => $c->stash('file_hash'), format => $c->stash('format'), uid => $user->uid});
}

sub _serve {
  my ($c, $params) = @_;
  my $user = $c->app->core->get_user_by_uid($params->{uid});
  my $file = Convos::Plugin::Files::File->new(id => $params->{fid}, user => $user,
    types => $c->app->types);

  state $type_can_be_embedded = qr{^(application/javascript|application/json|image|text)};

  return $c->reply->not_found unless $file->user;    # invalid uid
  return $file->load_p->then(sub {
    return $c->reply->not_found unless eval { $file->filename };    # invalid fid
    return $c->reply->not_found if $file->write_only;

    my $ct = $file->mime_type;
    my $h  = $c->res->headers;
    $h->cache_control('max-age=86400');
    return $c->render(file => file => $file)
      if !$params->{format} and $ct =~ m!$type_can_be_embedded!;

    $h->content_type($ct);
    $h->content_disposition(qq[attachment; filename="@{[$file->filename]}"])
      unless $ct =~ m!$type_can_be_embedded!;
    return $c->reply->asset($file->asset);
  });
}

sub _save_p {
  my ($c, $asset, $meta) = @_;
  $asset = $asset->to_file unless $asset->is_file;

  # The iPhone uploads every photo as "image.jpg"
  if ($meta->{filename} =~ /^image.jpe?g$/i) {
    my $n = time % 10000;
    $meta->{filename} = "IMG_$n.jpg";
  }

  return Convos::Plugin::Files::File->new(%$meta, asset => $asset, user => $c->backend->user)
    ->save_p;
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Files - A plugin for handling user assets

=head1 DESCRIPTION

L<Convos::Plugin::Files> is a L<Convos::Plugin> for handling uploading and
serving user assets.

=head1 METHODS

=head2 register

  $files->register($app, \%config);

Used to register this plugin i L<Convos>.

=head1 SEE ALSO

L<Convos>, L<Convos::Plugin::Files::File>.

=cut
