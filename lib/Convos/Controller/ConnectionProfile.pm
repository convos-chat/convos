package Convos::Controller::ConnectionProfile;
use Mojo::Base 'Mojolicious::Controller', -async_await;

use Convos::Core::Connection;
use Mojo::JSON qw(false true);

sub list {
  return unless my $self = shift->openapi->valid_input;
  return $self->reply->errors([], 401) unless $self->backend->user;

  my $admin_from = $self->user_has_admin_rights;
  return $self->render(
    openapi => {
      profiles => $self->app->core->connection_profiles->map(sub {
        my $json = shift->TO_JSON;
        delete $json->{webirc_password} unless $admin_from;
        return $json;
      })
    }
  );
}

async sub remove {
  return unless my $self = shift->openapi->valid_input;
  return $self->reply->errors([], 401) unless my $user = $self->backend->user;
  return $self->reply->errors('Only admins can delete connection profiles.', 403)
    unless $self->user_has_admin_rights;

  my $core = $self->app->core;
  my $json = $self->req->json;

  return $self->render(openapi => {message => 'Deleted.'})
    unless my $profile = $core->connection_profile({id => $self->stash('id')});

  return $self->render(openapi => {message => 'Deleted.'}) unless $profile->url->host;

  return $self->reply->errors('You cannot delete the default connection.', 400)
    if $core->settings->default_connection->host eq $profile->url->host;

  return $self->reply->errors('You must have at least one connection profile.', 400)
    if $core->n_connection_profiles <= 1;

  await $core->remove_connection_profile_p($profile);
  return $self->render(openapi => {message => 'Deleted.'});
}

async sub save {
  return unless my $self = shift->openapi->valid_input;
  return $self->reply->errors([], 401) unless my $user = $self->backend->user;
  return $self->reply->errors('Only admins can list users.', 403)
    unless $self->user_has_admin_rights;

  my $core    = $self->app->core;
  my $json    = $self->req->json;
  my $url     = Mojo::URL->new($json->{url});
  my $profile = $core->connection_profile({%$json, id => undef, url => $url});

  if ($json->{is_default}) {
    await $core->settings->default_connection($url->clone)
      ->forced_connection($json->{is_forced} ? true : false)->save_p;
  }

  $self->render(openapi => await $profile->save_p($json));
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::ConnectionProfile - API endpoint for connection profiles

=head1 DESCRIPTION

L<Convos::Controller::ConnectionProfile> is a L<Mojolicious::Controller> with
connection profile related actions.

=head1 METHODS

=head2 list

See L<https://convos.chat/api.html#op-get--connection-profiles>

=head2 remove

See L<https://convos.chat/api.html#op-delete--connection-profiles>

=head2 save

See L<https://convos.chat/api.html#op-post--connection-profiles>

=head1 SEE ALSO

L<Convos>.

=cut
