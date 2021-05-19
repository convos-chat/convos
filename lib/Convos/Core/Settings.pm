package Convos::Core::Settings;
use Mojo::Base -base;

use Convos::Core::Connection;
use Convos::Util 'generate_secret';
use Mojo::JSON qw(false true);
use Mojo::Path;
use Mojo::URL;

has base_url           => sub { Mojo::URL->new('http://127.0.0.1:8080') };
has contact            => 'mailto:root@localhost';
has core               => sub { Convos::Core->new }, weak => 1;
has id                 => 'settings';
has default_connection => sub { shift->_build_default_connection };
has forced_connection  => sub {false};
has local_secret       => sub { $ENV{CONVOS_LOCAL_SECRET} || generate_secret };
has open_to_public     => sub {false};
has organization_name  => 'Convos';
has organization_url   => sub { Mojo::URL->new('https://convos.chat') };
has session_secrets    => sub { shift->_build_session_secrets };
has video_service      => 'https://meet.jit.si/';

sub load_p {
  my $self = shift;
  return $self->core->backend->load_object_p($self)->then(sub { $self->_set_attributes(shift, 1) });
}

sub public_attributes {
  qw(contact default_connection forced_connection open_to_public organization_name organization_url video_service);
}

sub save_p {
  my $self = shift;
  $self->_set_attributes(shift, 0) if ref $_[0] eq 'HASH';

  my $url = $self->default_connection;
  $self->core->connection_profile({url => $url->clone});

  my $p = $self->core->backend->save_object_p($self, @_);
  return $p;
}

sub uri { Mojo::Path->new('settings.json') }

sub _build_default_connection {
  my $self = shift;
  my $url  = Mojo::URL->new('irc://irc.libera.chat:6697/%23convos');
  $self->core->connection_profile({url => $url->clone});
  return $url;
}

sub _build_session_secrets {
  my $self = shift;
  return [split /,/, $ENV{CONVOS_SECRETS} || ''] if $ENV{CONVOS_SECRETS};

  my $file    = $self->core->home->child('secrets');
  my $secrets = -r $file ? [split /‚/, $file->slurp] : [];
  $file->remove if -e $file;

  return @$secrets ? $secrets : [generate_secret];
}

sub _set_attributes {
  my ($self, $params, $safe_source) = @_;

  $self->$_($params->{$_})
    for grep { defined $params->{$_} }
    qw(contact forced_connection open_to_public organization_name video_service);

  $self->$_(Mojo::URL->new($params->{$_}))
    for grep { defined $params->{$_} } qw(base_url default_connection organization_url);

  if ($safe_source) {
    $self->$_($params->{$_}) for grep { $params->{$_} } qw(local_secret session_secrets);
  }

  return $self;
}

sub TO_JSON {
  my ($self, $persist) = @_;

  my %json = map { ($_ => $self->$_) } $self->public_attributes;
  $json{$_} = $self->$_->to_string for qw(base_url default_connection organization_url);

  if ($persist) {
    $json{local_secret}    = $self->local_secret;
    $json{session_secrets} = $self->session_secrets;
  }

  return \%json;
}

1;

=encoding utf8

=head1 NAME

Convos::Core::Settings - Convos settings

=head1 DESCRIPTION

L<Convos::Core::Settings> is a class used to model Convos server settings.

=head1 ATTRIBUTES

=head2 base_url

  $url = $settings->base_url;

Holds a L<Mojo::URL> object that holds the public location of this Convos
instance.

=head2 contact

  $str = $settings->contact;
  $settings = $settings->contact("mailto:root@localhost");

Holds a string with an URL to where the Convos admin can be contacted.

=head2 core

  $obj = $settings->core;

Holds a L<Convos::Core> object.

=head2 default_connection

  $url = $settings->default_connection;
  $settings = $settings->default_connection(Mojo::URL->new("irc://..."));

Holds a L<Mojo::URL> object with the default connection URL. Default value
is "irc://irc.libera.chat:6697/%23convos". (Subject to change)

=head2 forced_connection

  $bool = $settings->forced_connection;
  $settings = $settings->forced_connection(Mojo::JSON::true);

True if this instance of Convos can only connect to the L</default_connection>.

=head2 local_secret

  $str = $settings->local_secret;

Holds a local password/secret that can be used to run admin actions from
localhost.

=head2 open_to_public

  $bool = $settings->open_to_public;
  $settings = $settings->open_to_public(Mojo::JSON::true);

True if users can register without an invite link.

=head2 organization_name

  $str = $settings->organization_name;
  $settings = $settings->organization_name("Convos");

Can be used to customize the title and sidebars.

=head2 organization_url

  $url = $settings->organization_url;
  $settings = $settings->organization_url(Mojo::URL->new("https://..."));

Will be used together with a custom L</organization_name> to add links to your
organization in the Convos UI.

=head2 session_secrets

  $array_ref = $settings->session_secrets;

A list of strings used to make the session cookie safe. See also
L<Mojolicious/secrets> for a longer description.

=head2 uri

  $path = $settings->uri;

Holds a L<Mojo::Path> object, with the URI to where this object should be
stored.

=head2 video_service

  $str = $settings->video_service;
  $settings = $settings->video_service("https://meet.jit.si/");

=head1 METHODS

=head2 id

  $str = $settings->id;

Always returns "settings". Used by L<Convos::Core::Backend::File> and friends.

=head2 load_p

  $p = $settings->load_p;

Will save L</ATTRIBUTES> to persistent storage.
See L<Convos::Core::Backend/save_object> for details.

=head2 public_attributes

  @attr_names = $settings->public_attributes;

Returns a list of L</ATTRIBUTES> that are considered open_to_public.  Currently
that is: L</contact>, L</open_to_public>, L</organization_name> and
L</organization_url>.

=head2 save_p

  $p = $settings->save_p(\%attributes);

Will save L</ATTRIBUTES> to persistent storage. C<%attributes> is optional,
but willl be used to change the public L</ATTRIBUTES>.

See L<Convos::Core::Backend/save_object> for details.

=head1 SEE ALSO

L<Convos>.

=cut
