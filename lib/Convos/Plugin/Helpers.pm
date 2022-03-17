package Convos::Plugin::Helpers;
use Mojo::Base 'Convos::Plugin';

use Convos::Util qw(is_true);
use JSON::Validator::Error;
use LinkEmbedder;
use Mojo::JSON qw(decode_json);
use Mojo::Util qw(b64_decode);
use Syntax::Keyword::Try;

my $EXCEPTION_HELPER;

sub register {
  my ($self, $app, $config) = @_;

  $EXCEPTION_HELPER = $app->renderer->get_helper('reply.exception');

  $app->helper('js_session'      => \&_js_session);
  $app->helper('linkembedder'    => sub { state $l = LinkEmbedder->new });
  $app->helper('reply.errors'    => \&_reply_errors);
  $app->helper('reply.exception' => \&_exception);
  $app->helper('social'          => \&_social);

  $app->linkembedder->ua->insecure(1) if is_true 'ENV:LINK_EMBEDDER_ALLOW_INSECURE_SSL';
  $app->linkembedder->ua->$_(5) for qw(connect_timeout inactivity_timeout request_timeout);
}

sub _exception {
  my ($c, $err) = @_;
  $c->stash->{lang} ||= 'en';

  state $openapi = sub {
    my $errors = shift;
    $_->{message} =~ s!\sat\s\S+.*!!s for @$errors;
    return openapi => {errors => $errors};
  };

  if (ref $err eq 'HASH') {
    $c->app->log->error(Mojo::JSON::encode_json($err));
    return $c->render(
      status => delete $err->{status} || 500,
      $openapi->($err->{errors} || [{message => $err->{message}, path => '/'}]),
    );
  }
  elsif ($c->openapi->spec) {
    $c->app->log->error($err);
    return $c->render($openapi->([{message => "$err", path => '/'}]), status => 500);
  }
  else {
    return $EXCEPTION_HELPER->($c, $err);
  }
}

sub _js_session {
  my ($c, $name) = @_;
  my $stash = $c->stash;
  return $name ? $stash->{'convos.js.session'}{$name} : $stash->{'convos.js.session'}
    if $stash->{'convos.js.session'};

  my $cookie = $c->cookie('convos_js');
  $cookie = $cookie ? decode_json b64_decode $cookie : undef;
  $stash->{'convos.js.session'} = $cookie || {};
  return _js_session($c, $name);
}

sub _reply_errors {
  my ($self, $errors, $status) = @_;

  $errors = [["$errors"]] unless ref $errors eq 'ARRAY';
  $errors = [
    map {
      my ($msg, $path) = @$_;
      $msg =~ s! at \S+.*!!s;
      $msg =~ s!:\s.*!.!s;
      JSON::Validator::Error->new($path || '/', $msg);
    } @$errors
  ];

  $status ||= 501;
  $errors->[0] = JSON::Validator::Error->new('/', 'Need to log in first.')
    if $status == 401 and !@$errors;

  $self->render(json => {errors => $errors}, status => $status);
  return undef;
}

sub _social {
  my $c      = shift;
  my $social = $c->stash->{social} ||= {};

  # Defaults
  $social->{description} ||= 'A chat application that runs in your web browser';
  $social->{image}       ||= $c->url_for('/images/2020-05-28-convos-chat.jpg')->to_abs;
  $social->{url}         ||= $c->url_for('/')->to_abs;

  # Get
  return $social unless @_;

  # Set
  $social->{$_[0]} = $_[1];
  return $c;
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Helpers - Default helpers for Convos

=head1 DESCRIPTION

This L<Convos::Plugin> contains default helpers for L<Convos>.

=head1 HELPERS

=head2 reply.errors

  undef = $c->reply->errors([], 401);
  undef = $c->reply->errors([[$msg, $path], ...], $status);
  undef = $c->reply->errors($msg, $status);

Used to render an OpenAPI error response.

=head1 METHODS

=head2 register

  $plugin->register($app, \%config);

Called by L<Convos>, when registering this plugin.

=head1 SEE ALSO

L<Convos>.

=cut
