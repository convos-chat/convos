package Convos::Plugin::Auth::OpenID;
use Mojo::Base 'Convos::Plugin::Auth';

use Convos::Util qw(DEBUG require_module);
use Mojo::Promise;
use Mojo::UserAgent;

has _configuration => sub { die 'OpenID configuration not loaded' };
has _jwks => sub { die 'JWKs not loaded' };
has '_ua' => sub { Mojo::UserAgent->new };

sub issuer { shift->_configuration->{issuer} }
sub jwt { Mojo::JWT->new->add_jwkset(shift->_jwks) }

sub register {
  my ($self, $app) = @_;
  require_module('Mojolicious::Plugin::OAuth2');
  require_module('Mojo::JWT');
  # also probably needs Crypt::OpenSSL::RSA and Crypt::OpenSSL::Bignum

  my $ua = $self->_ua;
  my $url = Mojo::URL->new($ENV{CONVOS_OPENID_PROVIDER});
  push @{ $url->path }, '.well-known', 'openid-configuration';
  my $config = $ua->get($url)->result->json;
  $self->_configuration($config);

  my $jwks = $ua->get($config->{jwks_uri})->result->json;
  $self->_jwks($jwks);

  $app->plugin(OAuth2 => {
    $config->{issuer} => {
      key => $ENV{CONVOS_OPENID_KEY},
      secret => $ENV{CONVOS_OPENID_SECRET},
      authorize_url => $config->{authorization_endpoint},
      token_url => $config->{token_endpoint},
    }
  });

  $app->routes->get('/openid/login' => sub { $self->_login(@_) } => 'openid-login');

  $app->log->debug("Loaded Convos::Plugin::Auth::OpenID");
}

sub _login {
  my ($self, $c) = @_;

  my $token_args = {
    scope => 'openid',
    authorize_query => [
      response_type => 'code',
    ],
  };

  $c->oauth2->get_token_p($self->issuer => $token_args)->then(sub {
    return unless my $provider_res = shift; # Redirct to IdP
    #TODO handle error
    $c->session(token => $provider_res->{access_token});
    my $oid  = $self->jwt->decode($provider_res->{id_token});

    my $core = $c->app->core;
    my $user = $core->get_user($oid->{email});

    my $p = Mojo::Promise->resolve;
    unless ($user) {
      $user = $core->user({oid => $oid->{email}});
      $p = $p->then(sub{ $user->save_p });
    }

    return $p->then(sub{
      $c->session(email => $user->email);
      $c->redirect_to('/');
    });
  })->catch(sub {
    $c->render(openapi => {errors => [{message => shift, path => '/'}]}, status => 400);
  });
};

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Auth::OpenID - Convos plugin for logging in users via an OpenID provider

=head1 SYNOPSIS

  $ CONVOS_PLUGINS=Convos::Plugin::Auth::OpenID \
    CONVOS_OPENID_PROVIDER="http://accounts.google.com" \
    CONVOS_OPENID_KEY=my-app \
    CONVOS_OPENID_SECRET=secret \
    ./script/convos daemon

=head1 DESCRIPTION

L<Convos::Plugin::Auth::OpenID> allows Convos to register and login users via
an OAuth2 provider using OpenID Connect.

=head1 ENVIRONMENT VARIABLES

=head2 CONVOS_OPENID_PROVIDER

=head2 CONVOS_OPENID_KEY

=head2 CONVOS_OPENID_SECRET

=head1 METHODS

=head2 register

Used to register this plugin in the L<Convos> application.

=head1 SEE ALSO

L<Convos::Plugin::Auth> and L<Convos>.

=cut

