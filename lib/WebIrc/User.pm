package WebIrc::User;

=head1 NAME

WebIrc::User - Mojolicious controller for user data

=cut

use Mojo::Base 'Mojolicious::Controller';
use constant DEBUG => $ENV{WIRC_DEBUG} ? 1 : 0;

=head1 METHODS

=head2 auth

Check authentication and login

=cut

sub auth {
  my $self = shift;
  return 1 if $self->session('uid');
  $self->redirect_to('login');
  return 0;
}

=head2 login_or_register

Will either call L</login> or L</register> based on form input.

=cut

sub login_or_register {
  my $self = shift;

  $self->stash(template => 'index', form => '');

  if($self->req->method eq 'POST') {
    if(defined $self->param('email') or $self->stash('register_page')) {
      $self->stash(form => 'register');
      $self->register;
    }
    else {
      $self->stash(form => 'login');
      $self->login;
    }
  }
}

=head2 login

Authenticate local user

=cut

sub login {
  my $self = shift;

  $self->render_later;
  $self->app->core->login(
    {login => scalar $self->param('login'), password => scalar $self->param('password'),},
    sub {
      my ($core, $uid, $error) = @_;
      return $self->render(message => 'Invalid username/password.') unless $uid;
      $self->session(uid => $uid, login => $self->param('login'));

      $self->redis->smembers(
        "user:$uid:connections",
        sub {
          my ($redis, $conn) = @_;
          if (@$conn) {
            return $self->redirect_to('index');
          }
          $self->redirect_to('settings');
        }
      );
    },
  );
}

=head2 register

See L</login>.

=cut

sub register {
  my $self  = shift;
  my $admin = 0;

  if ($self->session('uid')) {
    $self->logf(debug => '[reg] Already logged in') if DEBUG;
    $self->redirect_to('settings');
    return;
  }

  $self->render_later;
  Mojo::IOLoop->delay(
    sub {
      my $delay = shift;
      $self->redis->get('user:uids', $delay->begin);
    },
    sub {    # Check invitation unless first user, or make admin.
      my ($delay, $uids) = @_;
      $self->logf(debug => '[reg] Got uids %s', $uids) if DEBUG;

      if ($self->_got_invalid_register_params($uids)) {
        $self->logf(debug => '[reg] Failed %s', $self->stash('errors')) if DEBUG;
        $self->render;
        return;
      }

      if ($uids) {
        $self->redis->get("user:@{[$self->param('login')]}:uid", $delay->begin);
      }
      else {
        $admin++;
        $self->logf(debug => '[reg] First login == admin') if DEBUG;
        $delay->begin->();
      }
    },
    sub {    # Get uid unless user exists
      my ($delay, $uid) = @_;
      if ($uid) {
        $self->stash->{errors}{login} = 'Username is taken.';
        $self->render;
      }
      else {
        $self->redis->incr('user:uids', $delay->begin);
      }
    },
    sub {    # Create user
      my ($delay, $uid) = @_;
      my $login = $self->param('login');
      my $digest = crypt $self->param('password'), join '',
        ('.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z')[rand 64, rand 64];
      $self->logf(debug => '[reg] New user uid=%s, login=%s', $uid, $self->param('login')) if DEBUG;
      $self->session(uid => $uid, login => $self->param('login'));
      $self->redis->execute(
        [set   => "user:$login:uid", $uid],
        [hmset => "user:$uid", digest => $digest, email => scalar $self->param('email')],
        $delay->begin,
      );
    },
    sub {
      my ($delay) = @_;
      $self->redirect_to('settings');
    }
  );
}

sub _got_invalid_register_params {
  my ($self, $secret_required) = @_;
  my $errors    = $self->stash('errors');
  my $email     = $self->param('email') || '';
  my @passwords = $self->param('password');

  if ($secret_required) {
    my $secret = $self->param('invite') || 'some-weird-secret-which-should-never-be-generated';
    $self->logf(debug => '[reg] Validating invite code %s', $secret) if DEBUG;
    if ($secret ne crypt($email . $self->app->secret, $secret) && $secret ne 'OPEN SESAME') {
      $self->logf(debug => '[reg] Invalid invite code.') if DEBUG;
      $errors->{invite} = 'You need a valid invite code to register.';
    }
  }

  if (($self->param('login') || '') !~ m/^[\w]{4,15}$/) {
    $errors->{login} = 'Username must consist of letters and numbers and be 4-15 characters long';
  }
  if (!$self->param('email') || $self->param('email') !~ m/.\@./) {
    $errors->{email} = 'Invalid email.';
  }

  if ((grep {$_} @passwords) != 2 or $passwords[0] ne $passwords[1]) {
    $errors->{password} = 'You need to enter the same password twice.';
  }
  elsif (length($passwords[0]) < 6) {
    $errors->{password} = 'The password must be at least 6 characters long';
  }

  return keys %$errors;
}

=head2 logout

Will delete data from session.

=cut

sub logout {
  my $self = shift;
  $self->session(uid => undef, login => undef);
  $self->redirect_to('/');
}

=head2 settings

Used to retrieve connection information.

=cut

sub settings {
  my $self   = shift->render_later;
  my $uid    = $self->session('uid');
  my $cid    = $self->stash('cid');
  my $hostname = WebIrc::Core::Util::hostname();
  my $login = $self->session('login');
  my (@actions, $cids, @connections);

  # cid is just to trick layouts/default.html.ep
  $self->stash(connections => \@connections, settings => 1, fqn => "$login\@$hostname");

  Mojo::IOLoop->delay(
    sub {    # get connections
      $self->redis->smembers("user:$uid:connections", $_[0]->begin);
    },
    sub {    # get connection data
      my $delay = shift;
      $cids = shift;
      $self->logf(debug => '[settings] connections %s', $cids) if DEBUG;
      $self->redis->execute(
        [get => "avatar:$login\@$hostname"],
        (map { [hgetall => "connection:$_"] } @$cids),
        (map { [smembers => "connection:$_:channels"] } @$cids),
        $delay->begin
      );
    },
    sub {    # convert connections to data structures
      my $delay = shift;
      my $avatar = shift || '';
      my $current;

      $self->logf(debug => '[settings] connection data %s', \@_) if DEBUG;

      for (my $i = 0; $i < @$cids; $i++) {
        my $info = $_[$i];
        $cid //= $cids->[$i];
        $info->{cid} = $cids->[$i];
        $info->{channels} = join ' ', sort @{ $_[@$cids + $i] };
        $current = $info if $info->{cid} eq $cid;
        push @connections, $info;
      }

      $current ||= $self->app->config->{default_connection};
      $current->{avatar} = $avatar;
      $self->stash(cid => $cid, current => $current);
      $self->render;
    },
  );
}

=head2 add_connection

Add a new connection.

=cut

sub add_connection {
  my $self = shift;
  my $action = $self->param('action') || '';
  my $hostname = WebIrc::Core::Util::hostname();
  my $login = $self->session('login');

  Mojo::IOLoop->delay(
    sub {
      $self->app->core->add_connection(
        $self->session('uid'),
        {
          host     => $self->param('host')     || '',
          nick     => $self->param('nick')     || '',
          channels => $self->param('channels') || '',
          user     => $login,
        },
        $_[0]->begin
      );
    },
    sub {
      my ($delay, $cid, $cname) = @_;
      unless ($cid) {
        $self->stash(errors => $cname, template => 'user/settings'); # cname is a hash-ref if $cid is undef
        $self->settings;
        return;
      }
      $self->logf(debug => '[settings] cid=%s', $cid) if DEBUG;
      $self->redis->publish('core:control', "start:$cid");
      $self->redis->set("avatar:$login\@$hostname", $self->param('avatar') || '');
      return $self->redirect_to('index') if $action eq 'connect';
      return $self->redirect_to('settings', cid => $cid);
    },
  );
}

=head2 edit_connection

Change a connection.

=cut

sub edit_connection {
  my $self = shift;
  my $action = $self->param('action') || '';
  my $cid = $self->param('cid');
  my $hostname = WebIrc::Core::Util::hostname();
  my $login = $self->session('login');

  Mojo::IOLoop->delay(
    sub {
      my $delay = shift;
      $self->redis->sismember("user:" . $self->session('uid') . ":connections", $cid, $delay->begin);
    },
    sub {
      my ($delay, $member) = @_;
      return $self->render_not_found unless $member;
      $self->logf(debug => '[settings] update %s', $cid) if DEBUG;
      $self->redis->set("avatar:$login\@$hostname", $self->param('avatar') || '');
      $self->app->core->update_connection(
        $cid,
        {
          host     => $self->param('host')     || '',
          nick     => $self->param('nick')     || '',
          channels => $self->param('channels') || '',
          user     => $login,
        },
        $delay->begin
      );
      $self->redis->publish('core:control', "restart:$cid");
    },
    sub {
      return $self->redirect_to('index') if $action eq 'connect';
      return $self->redirect_to('settings');
    }
  );
}

=head2 delete_connection

Delete a connection.

=cut

sub delete_connection {
  my $self = shift;
  my $uid  = $self->session('uid');
  my $cid  = $self->param('cid');

  $self->render_later;
  Mojo::IOLoop->delay(
    sub {
      my $delay = shift;
      $self->redis->sismember("user:" . $self->session('uid') . ":connections", $cid, $delay->begin);
    },
    sub {
      my ($delay, $member) = @_;
      return $self->render_not_found unless $member;
      $self->redis->publish("core:control", "stop:$cid");
      $self->redis->srem("user:$uid:connections", $cid, $delay->begin);
    },
    sub {
      my ($delay, $removed) = @_;
      return $self->render_not_found unless $removed;
      $self->redis->execute([keys => "connection:$cid:*"], $_[0]->begin);
    },
    sub {
      my ($delay, $keys) = @_;
      $self->redis->execute([del => @$keys], [srem => "connections", $cid], $delay->begin,);
    },
    sub {
      $self->redirect_to('settings');
    }
  );
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
