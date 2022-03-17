package Convos::Controller::Admin;
use Mojo::Base 'Mojolicious::Controller', -async_await;

use Convos::Util qw(disk_usage);
use Mojo::JSON qw(false true);
use Mojo::Util qw(trim);

async sub settings_get {
  my $self = shift->openapi->valid_input or return;
  return $self->reply->errors([], 401)
    unless $self->user->has_admin_rights(await $self->user->load_p);

  my $core     = $self->app->core;
  my $settings = $core->settings->TO_JSON;
  eval { $settings->{disk_usage} = disk_usage $core->home };
  $self->render(openapi => $settings);
}

async sub settings_update {
  my $self = shift->openapi->valid_input or return;
  return $self->reply->errors([], 401)
    unless $self->user->has_admin_rights(await $self->user->load_p);

  my ($err, $json) = $self->_clean_json($self->req->json);
  return $self->reply->errors($err, 400) if @$err;

  my $settings = await $self->app->core->settings->save_p($json);
  return $self->render(openapi => $settings);
}

sub _clean_json {
  my $self = shift;

  my $json  = $self->req->json;
  my %clean = map { ($_ => $json->{$_}) }
    grep { defined $json->{$_} } $self->app->core->settings->public_attributes;

  my @err;
  if ($clean{contact}) {
    push @err, ['Contact URL need to start with "mailto:".', '/email']
      unless $clean{contact} =~ m!^mailto:.*!;
  }

  if ($clean{default_connection}) {
    $clean{default_connection} = Mojo::URL->new(trim $clean{default_connection});
    push @err, ['Connection URL require a scheme and host.', '/default_connection']
      unless $clean{default_connection}->scheme eq 'irc' and $clean{default_connection}->host;
  }

  if ($clean{organization_url}) {
    $clean{organization_url} = Mojo::URL->new(trim $clean{organization_url});
    push @err, ['Organization URL require a scheme and host.', '/organization_url']
      unless $clean{organization_url}->scheme and $clean{organization_url}->host;
  }

  if ($clean{video_service}) {
    $clean{video_service} = trim $clean{video_service};
  }

  return \@err, \%clean;
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Admin - Convos admin actions

=head1 DESCRIPTION

L<Convos::Controller::Admin> is a L<Mojolicious::Controller> with
admin related actions.

=head1 METHODS

=head2 settings_get

See L<https://convos.chat/api.html#op-get--settings>

=head2 settings_update

See L<https://convos.chat/api.html#op-post--settings>

=head1 SEE ALSO

L<Convos>

=cut
