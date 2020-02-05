package Convos::Plugin::Auth::OAuth2;
use Mojo::Base 'Convos::Plugin::Auth';

use Convos::Util qw(DEBUG require_module);
use Mojo::Promise;

has _provider => '';

sub register {
  my ($self, $app, $config) = @_;
  require_module('Mojolicious::Plugin::OAuth2');

  my $provider = Mojo::URL->new($ENV{CONVOS_OAUTH2_PROVIDER});
  $self->_provider($provider->host);
  $app->plugin(OAuth2 => {$provider->host, $provider->query->to_hash});

  $app->helper('auth.login_p' => sub { $self->_login_p(@_) });
  $app->log->debug("Loaded Convos::Plugin::Auth::OAuth2");
}

sub _login_p {
  my ($self, $c, $params) = @_;
  my $p = Mojo::Promise->new;

  return $p->then(sub {
    my $ldap_msg = shift;
    my $core     = $c->app->core;
    my $user     = $core->get_user($params);

    # Try to fallback to local user on error
    if ($ldap_msg->code) {
      return $user if $user and $user->validate_password($params->{password});
      return Mojo::Promise->reject('Invalid email or password.');
    }

    # All good if user exists
    return $user if $user;

    $user = $core->user($params);
    $user->set_password($params->{password});
    return $user->save_p;
  });
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Auth::OAuth2 - Convos plugin for logging in users via an OAuth2 provider

=head1 SYNOPSIS

  $ CONVOS_PLUGINS=Convos::Plugin::Auth::OAuth2 \
    CONVOS_OAUTH2_PROVIDER="github?key=123&secret=secret" \
    ./script/convos daemon

=head1 DESCRIPTION

L<Convos::Plugin::Auth::OAuth2> allows Convos to register and login users via
an OAuth2 provider.

=head1 ENVIRONMENT VARIABLES

=head2 CONVOS_OAUTH2_PROVIDER

=head1 METHODS

=head2 register

Used to register this plugin in the L<Convos> application.

=head1 SEE ALSO

L<Convos::Plugin::Auth> and L<Convos>.

=cut

