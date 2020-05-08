package Convos::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util 'E';
use Mojo::DOM;
use Mojo::JSON qw(false true);
use Mojo::Util qw(hmac_sha1_sum trim);
use Socket qw(inet_aton AF_INET);

use constant INVITE_LINK_VALID_FOR => $ENV{CONVOS_INVITE_LINK_VALID_FOR} || 24;

sub delete {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;

  if (@{$self->app->core->users} <= 1) {
    return $self->render(openapi => E('You are the only user left.'), status => 400);
  }

  return $self->app->core->backend->delete_object_p($user)->then(sub {
    delete $self->session->{email};
    $self->render(openapi => {message => 'You have been erased.'});
  });
}

sub docs {
  my $self = shift;

  my $file = $self->app->static->file(sprintf 'docs/%s.html', $self->stash('doc_name'));
  return $self->redirect_to('/docs/module-util') unless $file;

  my $doc = Mojo::DOM->new($file->slurp);
  $doc->find('a[href]')->each(sub { $_[0]->{href} =~ s!^([/\w].*)\.html$!$1! });

  my %sections = (h1 => $doc->at('#main h1'), main => $doc->at('#main'), nav => $doc->at('nav'),);

  $sections{main}->at('h1')->remove;
  $sections{nav}->at('h2')->remove;

  $self->title($doc->at('title')->text);
  $self->render('user/docs', %sections);
}

sub generate_invite_link {
  my $self = shift->openapi->valid_input or return;
  return $self->unauthorized unless my $admin_from = $self->user_has_admin_rights;

  my $exp      = time + ($self->param('exp') || INVITE_LINK_VALID_FOR) * 3600;
  my $user     = $self->app->core->get_user($self->stash('email'));
  my $password = $user ? $user->password : $self->settings('local_secret');

  my $params
    = $self->_add_invite_token_to_params(
    {email => $self->stash('email'), exp => $exp, password => $password},
    $self->app->secrets->[0]);

  my $invite_url = $self->url_for('register');
  $invite_url->query->param($_ => $params->{$_}) for qw(email exp token);
  $invite_url = $invite_url->to_abs->to_string;

  my $existing = $user ? true : false;
  my $expires  = Mojo::Date->new($exp)->to_datetime;
  return $self->render(text => "---\nExisting: $existing\nExpires: $expires\nURL: $invite_url\n\n")
    if $admin_from eq 'local';
  return $self->render(openapi => {existing => $existing, expires => $expires, url => $invite_url});
}

sub get {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;

  return $user->get_p($self->req->url->query->to_hash)
    ->then(sub { $self->render(openapi => shift) });
}

sub login {
  my $self = shift->openapi->valid_input or return;

  return $self->auth->login_p($self->_clean_json)->then(
    sub {
      my $user = shift;
      $self->session(email => $user->email)->render(openapi => $user);
    },
    sub {
      $self->render(openapi => {errors => [{message => shift, path => '/'}]}, status => 400);
    },
  );
}

sub login_html {
  my $self = shift;
  return $self->session('email') ? $self->redirect_to('/') : $self->render('index');
}

sub logout {
  my $self = shift;    # Not a big deal if it's ->openapi->valid_input or not
  my $format = $self->stash('format') || 'json';

  return $self->auth->logout_p({})->then(sub {
    $self->session({expires => 1});
    return $self->redirect_to('/login') if $format eq 'html';
    return $self->render(openapi => {message => 'Logged out.'});
  });
}

sub redirect_if_not_logged_in {
  my $self = shift;
  return $self->redirect_to('/login') unless my $user = $self->backend->user;
  return $self->stash(load_user => 1, user => $user);
}

sub register {
  my $self = shift->openapi->valid_input or return;
  my $json = $self->_clean_json;
  my $user = $self->app->core->get_user($json->{email});

  # The first user can join without invite link
  if ($self->app->core->n_users) {

    # Validate input
    return $self->unauthorized('Convos registration is not open to public.')
      if !$json->{token} and !$self->settings('open_to_public');

    # TODO: Add test
    return $self->unauthorized('Email is taken.') if !$json->{token} and $user;

    return $self->unauthorized('Invalid token. You have to ask your Convos admin for a new link.')
      if $json->{token} and !$self->_is_valid_invite_token($user, {%$json});

    # Update existing user
    return $self->_update_user($json, $user) if $user;
  }

  # Register new user
  return $self->auth->register_p($json)->then(sub {
    $user = shift;
    $user->role(give => 'admin') if $self->app->core->n_users == 1;
    $self->session(email => $user->email);
    $self->backend->connection_create_p(Mojo::URL->new($self->settings('default_connection')));
  })->then(sub {
    my $connection = shift;
    $self->app->core->connect($connection);
    $self->render(openapi => $user);
  });
}

sub register_html {
  my $self = shift;

  if (my $conn_url = $self->param('uri')) {
    return if $self->_register_html_conn_url_redirect($conn_url);
    $self->settings(conn_url => $conn_url);
  }

  $self->_register_html_handle_invite_url;
  $self->render('index');
}

sub update {
  my $self = shift->openapi->valid_input or return;
  my $json = $self->_clean_json;
  my $user = $self->backend->user or return $self->unauthorized;

  # TODO: Add support for changing email

  return $self->render(openapi => $user) unless %$json;
  return $self->_update_user($json, $user);
}

sub theme {
  my $self  = shift;
  my $theme = $self->param('theme');

  for my $path ($self->app->core->home, @{$self->app->static->paths}) {
    my $file = Mojo::File->new($path, themes => "$theme.css");
    return $self->reply->file($file) if -e $file;
  }

  return $self->render(text => "/* $theme.css not found */\n", status => 404);
}

sub _add_invite_token_to_params {
  my ($self, $params, $secret) = @_;
  $params->{token}
    = hmac_sha1_sum join(':', map { $_ => $params->{$_} // '' } qw(email exp password)), $secret;
  return $params;
}

sub _clean_json {
  return {} unless my $json = shift->req->json;

  for my $k (qw(email password)) {
    next unless defined $json->{$k};
    $json->{$k} = trim $json->{$k};
    delete $json->{$k} unless length $json->{$k};
  }

  $json->{highlight_keywords} = [grep {/\w/} map { trim $_ } @{$json->{highlight_keywords}}]
    if $json->{highlight_keywords};

  return $json;
}

sub _existing_connection {
  my ($self, $url, $user) = @_;
  return undef unless my $host = $url->host;

  my @hosts_cb;
  push @hosts_cb, sub {$host};
  push @hosts_cb, sub { my $addr = inet_aton $host; $addr && gethostbyaddr $addr, AF_INET };

  for my $host_cb (@hosts_cb) {
    for my $conn (@{$user->connections}) {
      return unless my $url_host = $host_cb->();
      return $conn if index($conn->url->host, $url_host) >= 0;
    }
  }

  return undef;
}

sub _existing_dialog {
  my ($self, $url, $conn) = @_;
  return undef unless my $dialog_name = $url->path->[0];
  return $conn->get_dialog(lc $dialog_name);
}

sub _is_valid_invite_token {
  my ($self, $user, $params) = @_;

  $params->{password} = $user ? $user->password : $self->settings('local_secret');
  for my $secret (@{$self->app->secrets}) {
    my $generated = $self->_add_invite_token_to_params({%$params}, $secret);
    return 1 if $generated->{token} eq $params->{token};
  }

  return 0;
}

sub _register_html_conn_url_redirect {
  my $self     = shift;
  my $conn_url = Mojo::URL->new(shift);
  my $user     = $self->backend->user or return;

  my $existing_connection = $self->_existing_connection($conn_url, $user);
  my $existing_dialog
    = $existing_connection && $self->_existing_dialog($conn_url, $existing_connection);

  if ($existing_connection and $existing_dialog) {
    my $redirect_url = $self->url_for('/chat');
    push @{$redirect_url->path}, $existing_connection->id if $existing_connection;
    push @{$redirect_url->path}, $existing_dialog->id     if $existing_dialog;
    return $self->redirect_to($redirect_url);
  }
  elsif ($existing_connection) {
    my $redirect_url = $self->url_for('/settings/conversation');
    $redirect_url->query->param(connection_id => $existing_connection->id);
    $redirect_url->query->param(dialog_id     => $conn_url->path->[0] || '');
    return $self->redirect_to($redirect_url);
  }
  else {
    my $redirect_url = $self->url_for('/settings/connection');
    $redirect_url->query->param(uri => $conn_url);
    return $self->redirect_to($redirect_url);
  }

  return;
}

sub _register_html_handle_invite_url {
  my $self = shift;

  my $params
    = {token => $self->param('token'), email => $self->param('email'), exp => $self->param('exp')};

  return unless $params->{token} and $params->{email} and $params->{exp};
  return $self->stash(status => 410) if $params->{exp} =~ m!\D! or $params->{exp} < time;

  my $user = $self->app->core->get_user($params->{email});
  return $self->stash(status => 400) unless $self->_is_valid_invite_token($user, $params);

  $self->settings(existing_user => $user ? true : false);
}

sub _update_user {
  my ($self, $json, $user) = @_;

  $user->highlight_keywords($json->{highlight_keywords}) if $json->{highlight_keywords};
  $user->set_password($json->{password})                 if $json->{password};
  $user->save_p->then(sub {
    $self->session(email => $user->email);
    $self->render(openapi => $user);
  });
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::User - Convos user actions

=head1 DESCRIPTION

L<Convos::Controller::User> is a L<Mojolicious::Controller> with
user related actions.

=head1 METHODS

=head2 delete

See L<Convos::Manual::API/deleteUser>.

=head2 docs

Will render docs built with C<pnpm run generate-docs>.

=head2 generate_invite_link

See L<Convos::Manual::API/inviteUser>.

=head2 get

See L<Convos::Manual::API/getUser>.

=head2 login

See L<Convos::Manual::API/loginUser>.

=head2 login_html

Will redirect to "/" if already logged in.

=head2 logout

See L<Convos::Manual::API/logoutUser>.

=head2 redirect_if_not_logged_in

Used in a L<Mojolicious::Routes::Route/under> to respond with 302, if the user
does not have a valid session cookie.

=head2 register

See L<Convos::Manual::API/registerUser>.

=head2 register_html

Will handle the "uri" that can hold "irc://...." URLs.

=head2 theme

Render custom themes.

=head2 update

See L<Convos::Manual::API/updateUser>.

=head1 SEE ALSO

L<Convos>.

=cut
