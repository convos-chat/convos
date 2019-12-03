package Convos::Controller::Admin;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(false true);

sub settings_get {
  my $self = shift->openapi->valid_input or return;
  return $self->unauthorized unless $self->user_has_admin_rights;

  my $settings = $self->app->core->settings->TO_JSON;
  my $config   = $self->render(openapi => $settings);
}

sub settings_update {
  my $self = shift->openapi->valid_input or return;
  return $self->unauthorized unless $self->user_has_admin_rights;

  my ($err, $json) = $self->_clean_json($self->req->json);
  return $self->render(openapi => {errors => $err}, status => 400) if @$err;

  my $settings = $self->app->core->settings;
  $self->delay(
    sub { $settings->save($json, shift->begin) },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->render(openapi => $settings);
    }
  );
}

sub _clean_json {
  my $self = shift;

  my $json  = $self->req->json;
  my %clean = map { ($_ => $json->{$_}) }
    grep { defined $json->{$_} } @{$self->app->core->settings->public_attributes};

  my @err;
  if ($clean{contact}) {
    push @err, {message => 'Contact URL need to start with "mailto:".', path => '/email'}
      unless $clean{contact} =~ m!^mailto:.*!;
  }

  if ($clean{default_connection}) {
    $clean{default_connection} = Mojo::URL->new($clean{default_connection});
    push @err,
      {message => 'Connection URL require a scheme and host.', path => '/default_connection'}
      unless $clean{default_connection}->scheme eq 'irc' and $clean{default_connection}->host;
  }

  if ($clean{organization_url}) {
    $clean{organization_url} = Mojo::URL->new($clean{organization_url});
    push @err,
      {message => 'Organization URL require a scheme and host.', path => '/organization_url'}
      unless $clean{organization_url}->scheme =~ m!^http! and $clean{organization_url}->host;
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

See L<Convos::Manual::API/getSettings>.

=head2 settings_update

See L<Convos::Manual::API/updateSettings>.

=head1 SEE ALSO

L<Convos>

=cut
