package Convos::Controller::User;
use Mojo::Base 'Mojolicious::Controller', -async_await;

use Mojo::DOM;
use Mojo::JSON qw(false true);
use Mojo::Util qw(hmac_sha1_sum trim);
use Socket     qw(inet_aton AF_INET);
use Syntax::Keyword::Try;

use constant INVITE_LINK_VALID_FOR => $ENV{CONVOS_INVITE_LINK_VALID_FOR} || 24;
use constant RELOAD                => $ENV{CONVOS_RELOAD_DICTIONARIES} && 1;

has _email => sub {
  my $email = shift->param('email') || '';
  $email =~ s!\.json$!!;
  return trim $email;
};

sub check_if_ready {
  my $self = shift;
  return $self->stash(template => 'app') if $self->app->core->ready;
  $self->stash('openapi')
    ? $self->render(json => {errors => [{message => 'Backend is starting.'}]}, status => 503)
    : $self->render('loading', lang => 'en', status => 503);
  return 0;
}

sub dictionary {
  my $self = shift;
  $self->res->headers->cache_control(RELOAD ? 'no-cache' : 'max-age=86400');
  $self->render(
    json => {
      %{$self->i18n->meta($self->stash('lang'))},
      available_languages => $self->i18n->meta,
      dictionary          => $self->i18n->dictionary($self->stash('lang')),
    }
  );
}

async sub generate_invite_link {
  my $self       = shift->openapi->valid_input or return;
  my $admin_from = $self->user->has_admin_rights(await $self->user->load_p)
    or return $self->reply->errors([], 401);

  my $exp      = time + ($self->param('exp') || INVITE_LINK_VALID_FOR) * 3600;
  my $user     = $self->app->core->get_user($self->_email);
  my $password = $user ? $user->password : $self->app->core->settings->local_secret;

  my $params
    = $self->_add_invite_token_to_params(
    {email => $self->_email, exp => $exp, password => $password},
    $self->app->secrets->[0]);

  my $invite_url = $self->url_for('register');
  $invite_url->query->param($_ => $params->{$_}) for qw(email exp token);
  $invite_url = $self->app->core->web_url($invite_url)->to_abs->to_string;

  my $existing = $user ? true : false;
  my $expires  = Mojo::Date->new($exp)->to_datetime;
  return $self->render(text => "---\nExisting: $existing\nExpires: $expires\nURL: $invite_url\n\n")
    if $admin_from eq 'local';
  return $self->render(openapi => {existing => $existing, expires => $expires, url => $invite_url});
}

async sub get {
  my $self     = shift->openapi->valid_input or return;
  my $user     = await $self->user->load_p   or return $self->reply->errors([], 401);
  my $info     = await $user->get_p($self->req->url->query->to_hash);
  my $settings = $self->app->core->settings;
  $info->{default_connection} = $settings->default_connection_safe->to_string;
  $info->{forced_connection}  = $settings->forced_connection;
  $info->{video_service}      = $settings->video_service;
  $self->render(openapi => $info);
}

async sub list {
  my $self = shift->openapi->valid_input or return;
  return $self->reply->errors('Only admins can list users.', 403)
    unless $self->user->has_admin_rights(await $self->user->load_p);

  my $users = $self->app->core->users;
  $self->render(openapi => {users => $users});
}

async sub login {
  my $self = shift->openapi->valid_input or return;

  try {
    my $user = await $self->auth->login_p($self->_clean_json);
    $self->session(email => $user->email)->render(openapi => $user);
  }
  catch ($err) {
    $self->reply->exception({message => $err, status => 400});
  }
}

async sub logout {
  my $self = shift;    # Not a big deal if it's ->openapi->valid_input or not

  return $self->reply->exception('Invalid csrf token')
    unless +($self->param('csrf') // 'does_not_match') eq $self->csrf_token;

  await $self->auth->logout_p({});
  $self->session({expires => 1});
  return $self->redirect_to('/login');
}

async sub register {
  my $self = shift->openapi->valid_input or return;
  my $json = $self->_clean_json;
  my $user = $self->app->core->get_user($json->{email});

  # Only the first user can join without invite link
  if ($self->app->core->n_users) {

    # Validate input
    return $self->reply->errors('Convos registration is not open to public.', 401)
      if !$json->{token} and !$self->app->core->settings->open_to_public;

    # TODO: Add test
    return $self->reply->errors('Email is taken.', 401) if !$json->{token} and $user;

    if ($json->{token} and !$self->_is_valid_invite_token($user, {%$json})) {
      return $self->reply->errors(
        'Invalid token. You have to ask your Convos admin for a new link.', 401);
    }

    # Update existing user
    return await $self->_update_user_p($user, $user, $json) if $user;
  }

  # Register new user
  $user = await $self->auth->register_p($json);
  $self->session(email => $user->email);
  await $self->user->initial_setup_p($user);
  $self->render(openapi => $user);
}

async sub register_html {
  my $self = shift;

  my $conn_url = $self->param('uri');
  return if $conn_url and await $self->_register_html_conn_url_redirect_p($conn_url);

  $self->_register_html_handle_invite_url;
  $self->render('app');
}

async sub remove {
  my $self  = shift->openapi->valid_input or return;
  my $admin = await $self->user->load_p   or return $self->reply->errors([], 401);
  my $user  = await $self->_get_user_from_param_p($admin, 'delete') or return;

  return $self->reply->errors('You are the only user left.', 400)
    if @{$self->app->core->users} <= 1;

  await $self->app->core->remove_user_p($user);
  delete $self->session->{email} if $user->email eq $self->session('email');
  $self->render(openapi => {message => 'Deleted.'});
}

async sub update {
  my $self  = shift->openapi->valid_input or return;
  my $admin = await $self->user->load_p   or return $self->reply->errors([], 401);
  my $user  = await $self->_get_user_from_param_p($admin, 'update') or return;
  my $json  = $self->_clean_json;

  # TODO: Add support for changing email

  return $self->render(openapi => $user) unless %$json;
  return await $self->_update_user_p($admin, $user, $json);
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

  for my $k (qw(highlight_keywords roles)) {
    $json->{$k} = [grep {/\w/} map { trim $_ } @{$json->{$k}}] if $json->{$k};
  }

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

sub _existing_conversation {
  my ($self, $url, $conn) = @_;
  return undef unless my $conversation_name = $url->path->[0];
  return $conn->get_conversation(lc $conversation_name);
}

async sub _get_user_from_param_p {
  my ($self, $admin, $op) = @_;
  return $admin if $admin->email eq $self->_email;
  return $self->reply->errors("Only admins can $op other users.", 403)
    unless $self->user->has_admin_rights($admin);

  my $user = $self->app->core->get_user($self->_email);
  return $user                                                          if $user;
  return +($self->render(openapi => {message => 'Deleted.'}), undef)[1] if $op eq 'delete';
  return $self->reply->errors('No such user.', 404);
}

sub _is_valid_invite_token {
  my ($self, $user, $params) = @_;

  $params->{password} = $user ? $user->password : $self->app->core->settings->local_secret;
  for my $secret (@{$self->app->secrets}) {
    my $generated = $self->_add_invite_token_to_params({%$params}, $secret);
    return 1 if $generated->{token} eq $params->{token};
  }

  return 0;
}

async sub _register_html_conn_url_redirect_p {
  my $self     = shift;
  my $conn_url = Mojo::URL->new(shift);
  my $user     = await $self->user->load_p or return undef;

  my $existing_connection = $self->_existing_connection($conn_url, $user);
  my $existing_conversation
    = $existing_connection && $self->_existing_conversation($conn_url, $existing_connection);

  if ($existing_connection and $existing_conversation) {
    my $redirect_url = $self->url_for('/chat');
    push @{$redirect_url->path}, $existing_connection->id   if $existing_connection;
    push @{$redirect_url->path}, $existing_conversation->id if $existing_conversation;
    return $self->redirect_to($redirect_url);
  }
  elsif ($existing_connection) {
    my $redirect_url = $self->url_for('/settings/conversation');
    $redirect_url->query->param(connection_id   => $existing_connection->id);
    $redirect_url->query->param(conversation_id => $conn_url->path->[0] || '');
    return $self->redirect_to($redirect_url);
  }
  else {
    my $redirect_url = $self->url_for('/settings/connection/add');
    $redirect_url->query->param(uri => $conn_url);
    return $self->redirect_to($redirect_url);
  }

  return;
}

sub _register_html_handle_invite_url {
  my $self = shift;

  my $params = {token => $self->param('token'), email => $self->_email, exp => $self->param('exp')};
  return unless $params->{token} and $params->{email} and $params->{exp};
  return $self->stash(status => 410) if $params->{exp} =~ m!\D! or $params->{exp} < time;

  my $user = $self->app->core->get_user($params->{email});
  return $self->stash(status        => 400) unless $self->_is_valid_invite_token($user, $params);
  return $self->stash(existing_user => $user ? 1 : 0);
}

async sub _update_user_p {
  my ($self, $admin, $user, $json) = @_;

  $user->highlight_keywords($json->{highlight_keywords}) if $json->{highlight_keywords};
  $user->roles($json->{roles}) if $json->{roles} and $self->user->has_admin_rights($admin);
  $user->set_password($json->{password}) if $json->{password};
  await $user->save_p;
  my $session_email = $self->session('email');
  $self->session(email => $user->email) if !$session_email or $user->email eq $session_email;
  $self->render(openapi => $user);
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::User - Convos user actions

=head1 DESCRIPTION

L<Convos::Controller::User> is a L<Mojolicious::Controller> with
user related actions.

=head1 METHODS

=head2 check_if_ready

Will render the "loading" template if L<Convos::Core/ready> is false or set
"app" to be rendered if core is ready.

=head2 dictionary

See L<https://convos.chat/api.html#op-get--dictionary>

=head2 generate_invite_link

See L<https://convos.chat/api.html#op-post--user--email--invite>

=head2 get

See L<https://convos.chat/api.html#op-get--user>

=head2 list

See L<https://convos.chat/api.html#op-get--users>

=head2 login

See L<https://convos.chat/api.html#op-post--user-login>

=head2 logout

See L<https://convos.chat/api.html#op-get--user-logout>

=head2 register

See L<https://convos.chat/api.html#op-post--user-register>

=head2 register_html

Will handle the "uri" that can hold "irc://...." URLs.

=head2 remove

See L<https://convos.chat/api.html#op-delete--user>

=head2 update

See L<https://convos.chat/api.html#op-post--user>

=head1 SEE ALSO

L<Convos>.

=cut
