package Convos::Plugin::Auth::LDAP;
use Mojo::Base 'Convos::Plugin::Auth';

use Convos::Util qw(DEBUG require_module);
use Mojo::Promise;

has _ldap_options => undef;
has _ldap_url     => undef;
has _reactor      => sub { Mojo::IOLoop->singleton->reactor };

sub register {
  my ($self, $app, $config) = @_;

  # Allow ldap url with options: ldaps://ldap.example.com?debug=1&timeout=10
  my $ldap_url = Mojo::URL->new($ENV{CONVOS_AUTH_LDAP_URL} || 'ldap://localhost:389');
  $self->_ldap_options($ldap_url->query->to_hash);
  $self->_ldap_options->{timeout} ||= 10;
  $self->_ldap_url($ldap_url->query(Mojo::Parameters->new));

  # Make sure Net::LDAP is installed
  require_module('Net::LDAP');

  $app->helper('auth.login_p' => sub { $self->_login_p(@_) });
  $app->log->debug("Loaded Convos::Plugin::Auth::LDAP $ldap_url");
}

sub _bind_params {
  my ($self, $params) = @_;

  # Convert "user@example.com" into (uid => "user", domain => "example", tld => "com");
  my %dn = (email => $params->{email});
  @dn{qw(uid domain)} = split '@', $params->{email};
  $dn{tld} = $dn{domain} =~ s!\.(\w+)$!! ? $1 : '';

  # Place email values into the DN string
  my $dn = $ENV{CONVOS_AUTH_LDAP_DN};
  $dn ||= $dn{tld} ? 'uid=%uid,dc=%domain,dc=%tld' : 'uid=%uid,dc=%domain';
  $dn =~ s!%(domain|email|tld|uid)!{$dn{$1} || ''}!ge;

  return ($dn, password => $params->{password});
}

sub _ldap {
  my $self = shift;

  my $ldap = Net::LDAP->new($self->_ldap_url->to_unsafe_string, %{$self->_ldap_options}, async => 1)
    or die "Could not create Net::LDAP object: $@";

  # Make the operation non-blocking together with "async => 1" above
  $self->_reactor->io($ldap->socket, sub { $ldap->process });

  return $ldap;
}

sub _login_p {
  my ($self, $c, $params) = @_;

  my $p    = Mojo::Promise->new;
  my $ldap = $self->_ldap;
  $ldap->bind($self->_bind_params($params),
    callback => sub { $self->_disconnect($ldap); $p->resolve(@_) });

  return $p->then(sub {
    my $ldap_msg = shift;
    my $core     = $c->app->core;
    my $user     = $core->get_user($params);

    warn sprintf "[LDAP/%s] code=%s, exists=%s\n", $params->{email}, $ldap_msg->code,
      $user ? 'yes' : 'no'
      if DEBUG;

    # Try to fallback to local user on error
    if ($ldap_msg->code) {
      return $user if $user and $user->validate_password($params->{password});
      return Mojo::Promise->reject('Invalid email or password.');
    }

    # All good if user exists
    return $user if $user;

    # Create new user, since authenticated by LDAP
    warn sprintf "[LDAP/%s] code=%s, created=yes\n", $params->{email}, $ldap_msg->code if DEBUG;
    $user = $core->user($params);
    $user->set_password($params->{password});
    return $user->save_p;
  });
}

sub _disconnect {
  my $self = shift;
  my $ldap = shift or return;
  $self->_reactor->remove($ldap->socket);
  $ldap->disconnect;
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Auth::LDAP - Convos plugin for logging in users from LDAP

=head1 SYNOPSIS

  $ CONVOS_PLUGINS=Convos::Plugin::Auth::LDAP \
    CONVOS_AUTH_LDAP_URL="ldap://localhost:389" \
    CONVOS_AUTH_LDAP_DN="uid=%uid,dc=%domain,dc=%tld" \
    ./script/convos daemon

=head1 DESCRIPTION

L<Convos::Plugin::Auth::LDAP> allows Convos to register and login users from
an LDAP database.

=head1 ENVIRONMENT VARIABLES

=head2 CONVOS_AUTH_LDAP_DN

C<CONVOS_AUTH_LDAP_DN> defaults to "uid=%uid,dc=%domain,dc=%tld" (EXPERIMENTAL),
but can be set to any value you like. The "%named" parameters can be "%email",
"%uid", "%domain" and "%tld", which will be extracted from the email address of
the user. Example:

  CONVOS_AUTH_LDAP_DN = "uid=%uid,dc=%domain,dc=%tld"
  email = "superwoman@example.com"
  dn = "uid=superwoman,dc=example,dc=com"

=head2 CONVOS_AUTH_LDAP_URL

The URL to the LDAP server. Default is "ldap://localhost:389". (EXPERIMENTAL)

You can add LDAP config parameters to the URL. See L<Net::LDAP> for more
information.

  ldap://ldap.example.com?debug=1&timeout=10

Want to connect securily? Change "ldap://" to "ldaps://"

=head1 METHODS

=head2 register

Used to register this plugin in the L<Convos> application.

=head1 SEE ALSO

L<Convos::Plugin::Auth> and L<Convos>.

=cut
