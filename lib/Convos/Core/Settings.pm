package Convos::Core::Settings;
use Mojo::Base -base;

use Mojo::JSON qw(false true);
use Mojo::Path;
use Mojo::URL;
use Mojo::Util;

has contact => sub { $ENV{CONVOS_CONTACT} || 'mailto:root@localhost' };
sub core { shift->{core} or die 'core is required in constructor' }
has default_connection => \&_build_default_connection;
has forced_connection =>
  sub { $ENV{CONVOS_FORCED_CONNECTION} || $ENV{CONVOS_FORCED_IRC_SERVER} ? true : false };
sub id {'settings'}
has local_secret   => \&_build_local_secret;
has open_to_public => sub {false};
has organization_name =>
  sub { $ENV{CONVOS_ORGANIZATION_NAME} || shift->defaults->{organization_name} };
has organization_url =>
  sub { Mojo::URL->new($ENV{CONVOS_ORGANIZATION_URL} || shift->defaults->{organization_url}) };

sub public_attributes {
  return [
    qw(contact default_connection forced_connection),
    qw(open_to_public organization_name organization_url),
  ];
}

has rtc => sub {
  my $self = shift;
  my $config;

  for my $type (qw(stun turn)) {
    my $env_key = sprintf 'CONVOS_%s', uc $type;
    my $url     = Mojo::URL->new($ENV{$env_key} // "$type://");
    next unless $url->host;

    $config ||= $url->query->to_hash;
    my $server = {urls => sprintf '%s:%s', $url->scheme || 'stun', $url->host_port};
    $server->{username}   = $url->username if $url->username;
    $server->{credential} = $url->password if $url->password;
    $server->{credential_type} = $url->query->param('credentialType') // 'password'
      if $url->query->param('credentialType')
      or $url->password;
    push @{$config->{ice_servers}}, $server;
  }

  $config ||= {};
  delete $config->{credentialType};
  return $config;
};

has session_secrets => \&_build_session_secrets;

sub defaults {
  return {organization_name => 'Convos', organization_url => 'https://convos.chat'};
}

sub load_p {
  my $self = shift;
  return $self->core->backend->load_object_p($self)->then(sub { $self->_set_attributes(shift, 1) });
}

sub save_p {
  my $self = shift;

  $self->_set_attributes(shift, 0) if ref $_[0] eq 'HASH';
  my $p = $self->core->backend->save_object_p($self, @_);

  # Remove legacy secrets file
  my $file = $self->_legacy_session_secrets_file;
  $file->remove if -e $file;

  return $p;
}

sub uri { Mojo::Path->new('settings.json') }

sub _build_default_connection {
  my $self = shift;

  my @urls = map { $ENV{uc("CONVOS_$_")} // '' }
    qw(forced_connection forced_irc_server default_connection default_server);

  for my $url (grep {$_} @urls) {
    next unless 3 < length $url;    # skip "0", "1" and "yes"
    $url = "irc://$url" unless $url =~ m!^\w+://!;
    return Mojo::URL->new($url);
  }

  return Mojo::URL->new('irc://chat.freenode.net:6697/%23convos');
}

sub _build_local_secret {
  my $self = shift;
  return $ENV{CONVOS_LOCAL_SECRET} if $ENV{CONVOS_LOCAL_SECRET};

  my $secret = Mojo::Util::md5_sum(join ':', $self->core->home->to_string, $<, $(, $0);
  return $secret;
}

sub _build_session_secrets {
  my $self = shift;
  return [split /,/, $ENV{CONVOS_SECRETS} || ''] if $ENV{CONVOS_SECRETS};

  my $secrets;
  my $file = $self->_legacy_session_secrets_file;
  $secrets = [split /‚/, $file->slurp] if -e $file;
  return $secrets if $secrets and @$secrets;

  $secrets = [Mojo::Util::sha1_sum(join ':', rand(), $$, $<, $(, $^X, Time::HiRes::time())];
  return $secrets;
}

sub _legacy_session_secrets_file { shift->core->home->child('secrets') }

sub _set_attributes {
  my ($self, $params, $safe_source) = @_;

  $self->$_($params->{$_})
    for grep { defined $params->{$_} }
    qw(contact forced_connection open_to_public organization_name);

  $self->$_(Mojo::URL->new($params->{$_}))
    for grep { defined $params->{$_} } qw(default_connection organization_url);

  if ($safe_source) {
    $self->$_($params->{$_}) for grep { defined $params->{$_} } qw(local_secret session_secrets);
  }

  return $self;
}

sub TO_JSON {
  my ($self, $persist) = @_;

  my %json = map { ($_ => $self->$_) } @{$self->public_attributes};
  $json{$_} = $json{$_}->to_string for qw(default_connection organization_url);

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
is "irc://chat.freenode.net:6697/%23convos". (Subject to change)

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

=head2 public_attributes

  $array_ref = $settings->public_attributes;

Returns a list of L</ATTRIBUTES> that are considered open_to_public.
Currently that is: L</contact>, L</default_connection>,
L</forced_connection>, L</open_to_public>, L</organization_name> and
L</organization_url>.

=head2 rtc

  $hash_ref = $settings->rtc;

Holds information about how to set up a
L<https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection>. For now,
it can be configured with an environment variable. Example:

  # Required for signalling
  CONVOS_STUN=stun://superwoman:kryptonite@stun.example.com:3478?&bundlePolicy=balanced&credentialType=password&iceTransportPolicy=all&rtcpMuxPolicy=require

  # Required for audio/video if NAT traversing is impossible
  CONVOS_TURN=turn://superwoman:kryptonite@stun.example.com:3478

The URL above will result in the C<RTCPeerConnection> object with the following
parameters:

  new RTCPeerConnection({
    bundlePolicy: "balanced",   // optional
    iceTransportPolicy: "all",  // optional
    rtcpMuxPolicy: "require",   // optional
    iceServers: [
      {
        urls: "stun:stun.example.com:3478",  // required
        credential: "kryptonite",            // optional
        credentialType: "password",          // optional
        username: "superwoman",              // optional
      },
      {
        urls            => 'turn:turn.example.com:3478',
        credential      => 'k2',
        credential_type => 'password',
        username        => 'superman',
      },
    ],
  })

The simplest version of C<CONVOS_RTC> can be seen below, meaning all the query
parameters and credentials are optional:

  CONVOS_RTC=stun://stun.example.com:3478

IMPORTANT! The username and password will be visible inside the browser's
developer tools, but you have to be logged in to see it.

=head2 session_secrets

  $array_ref = $settings->session_secrets;

A list of strings used to make the session cookie safe. See also
L<Mojolicious/secrets> for a longer description.

=head2 uri

  $path = $settings->uri;

Holds a L<Mojo::Path> object, with the URI to where this object should be
stored.

=head1 METHODS

=head2 defaults

  $hash_ref = $settings->defaults;

Returns default settings.

=head2 id

  $str = $settings->id;

Always returns "settings". Used by L<Convos::Core::Backend::File> and friends.

=head2 load_p

  $p = $settings->load_p;

Will save L</ATTRIBUTES> to persistent storage.
See L<Convos::Core::Backend/save_object> for details.

=head2 save_p

  $p = $settings->save_p(\%attributes);

Will save L</ATTRIBUTES> to persistent storage. C<%attributes> is optional,
but willl be used to change the public L</ATTRIBUTES>.

See L<Convos::Core::Backend/save_object> for details.

=head1 SEE ALSO

L<Convos>.

=cut
