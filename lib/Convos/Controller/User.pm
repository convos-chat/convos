package Convos::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

use Convos::Util 'E';
use Mojo::DOM;
use Mojo::Util 'trim';
use Socket qw(inet_aton AF_INET);

use constant RECOVERY_LINK_VALID_FOR => $ENV{CONVOS_RECOVERY_LINK_VALID_FOR} || 3600 * 6;

sub delete {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;

  if (@{$self->app->core->users} <= 1) {
    return $self->render(openapi => E('You are the only user left.'), status => 400);
  }

  $self->delay(
    sub { $self->app->core->backend->delete_object($user, shift->begin) },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      delete $self->session->{email};
      $self->render(openapi => {message => 'You have been erased.'});
    },
  );
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

sub generate_recover_link {
  my $self  = shift;
  my $email = $self->stash('email');
  my $exp   = time - int(rand 3600) + RECOVERY_LINK_VALID_FOR + 1800;
  my $check = Mojo::Util::hmac_sha1_sum("$email/$exp", $self->app->secrets->[0]);

  $self->render(text => $self->url_for(recover => {check => $check, exp => $exp}));
}

sub get {
  my $self = shift->openapi->valid_input or return;
  my $user = $self->backend->user        or return $self->unauthorized;

  $self->delay(
    sub { $user->get($self->req->url->query->to_hash, shift->begin); },
    sub {
      my ($delay, $err, $res) = @_;
      die $err if $err;
      $self->render(openapi => $res);
    }
  );
}

sub login {
  my $self = shift->openapi->valid_input or return;

  $self->delay(
    sub { $self->auth->login($self->_clean_json, shift->begin) },
    sub {
      my ($delay, $err, $user) = @_;
      return $self->render(openapi => E($err), status => 400) if $err;
      return $self->session(email => $user->email)->render(openapi => $user);
    },
  );
}

sub logout {
  my $self   = shift->openapi->valid_input or return;
  my $format = $self->stash('format') || 'json';

  $self->delay(
    sub { $self->auth->logout({}, shift->begin) },
    sub {
      my ($delay, $err) = @_;
      return $self->render(openapi => E($err), status => 500) if $err;
      $self->session({expires => 1});
      return $self->redirect_to('/') if $format eq 'html';
      return $self->render(openapi => {message => 'Logged out.'});
    },
  );
}

sub recover {
  my $self  = shift;
  my $email = $self->stash('email');
  my $exp   = $self->stash('exp');
  my $redirect_url;

  # expired
  return $self->render('index', status => 410) if $exp < time;

  for my $secret (@{$self->app->secrets}) {
    my $check = Mojo::Util::hmac_sha1_sum("$email/$exp", $secret);
    next if $check ne $self->stash('check');
    $redirect_url = $self->url_for('index');
    last;
  }

  return $self->render('index', status => 400) unless $redirect_url;

  $self->flash(main => '#profile');
  $self->session(email => $email)->redirect_to($redirect_url);
}

sub register {
  my $self = shift->openapi->valid_input or return;
  my $user;

  $self->delay(
    sub { $self->auth->register($self->_clean_json, shift->begin) },
    sub {
      (my ($delay, $err), $user) = @_;
      return $self->render(openapi => E($err), status => 400) if $err;
      $self->session(email => $user->email);
      $self->backend->connection_create($self->config('default_connection'), shift->begin);
    },
    sub {
      my ($delay, $err, $connection) = @_;
      return $self->render(openapi => E($err), status => 500) if $err;
      $self->app->core->connect($connection);
      $self->render(openapi => $user);
    },
  );
}

sub register_html {
  my $self     = shift;
  my $user     = $self->backend->user;
  my $conn_url = $self->param('uri') && Mojo::URL->new($self->param('uri'));

  if ($user and $conn_url) {
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
      my $redirect_url = $self->url_for('/add/conversation');
      $redirect_url->query->param(connection_id => $existing_connection->id);
      $redirect_url->query->param(dialog_id     => $conn_url->path->[0] || '');
      return $self->redirect_to($redirect_url);
    }
    else {
      my $redirect_url = $self->url_for('/add/connection');
      $redirect_url->query->param(uri => $conn_url);
      return $self->redirect_to($redirect_url);
    }
  }

  $self->settings(conn_url => $conn_url->to_string) if $conn_url;
  $self->render('index');
}

sub require_login {
  my $self = shift;
  my $user = $self->backend->user;

  unless ($user) {
    $self->redirect_to('index');
    return undef;
  }

  Mojo::IOLoop->delay(
    sub {
      my %get = map { ($_ => 1) } qw(connections dialogs);
      $user->get(\%get, shift->begin);
    },
    sub {
      my ($delay, $err, $res) = @_;
      return $self->helpers->reply->exception($err) if $err;
      $self->settings(user => $res);
      $self->continue;
    },
  );

  return undef;
}

sub update {
  my $self = shift->openapi->valid_input or return;
  my $json = $self->_clean_json;
  my $user = $self->backend->user or return $self->unauthorized;

  # TODO: Add support for changing email

  return $self->render(openapi => $user) unless %$json;
  return $self->delay(
    sub {
      my ($delay) = @_;
      $user->highlight_keywords($json->{highlight_keywords}) if $json->{highlight_keywords};
      $user->set_password($json->{password})                 if $json->{password};
      $user->save($delay->begin);
    },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->render(openapi => $user);
    },
  );
}

sub _existing_connection {
  my ($self, $url, $user) = @_;
  return undef unless my $host = $url->host;

  my @hosts;
  push @hosts, sub {$host};
  push @hosts, sub { my $addr = inet_aton $host; $addr && gethostbyaddr $addr, AF_INET };

  for my $host (@hosts) {
    for my $conn (@{$user->connections}) {
      return unless my $url_host = $host->();
      return $conn if index($conn->url->host, $url_host) >= 0;
    }
  }

  return undef;
}

sub _clean_json {
  return {} unless my $json = shift->req->json;

  for my $k (qw(email invite_code password)) {
    next unless defined $json->{$k};
    $json->{$k} = trim $json->{$k};
    delete $json->{$k} unless length $json->{$k};
  }

  $json->{highlight_keywords} = [grep {/\w/} map { trim $_ } @{$json->{highlight_keywords}}]
    if $json->{highlight_keywords};

  return $json;
}

sub _existing_dialog {
  my ($self, $url, $conn) = @_;
  return undef unless my $dialog_name = $url->path->[0];
  return $conn->get_dialog(lc $dialog_name);
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

=head2 generate_recover_link

Used to generate a recover link when running Convos from the command line.

=head2 get

See L<Convos::Manual::API/getUser>.

=head2 login

See L<Convos::Manual::API/loginUser>.

=head2 logout

See L<Convos::Manual::API/logoutUser>.

=head2 recover

Will log in a user from a recovery link.

=head2 require_login

TODO

=head2 register

See L<Convos::Manual::API/registerUser>.

=head2 register_html

Will handle the "uri" that can hold "irc://...." URLs.

=head2 update

See L<Convos::Manual::API/updateUser>.

=head1 SEE ALSO

L<Convos>.

=cut
