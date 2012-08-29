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
  my $self=shift;
  return 1 if $self->session('uid');
  $self->redirect_to('login');
  return 0;
}

=head2 login

Authenticate local user

=cut

sub login {
  my $self=shift;

  $self->render_later;
  $self->app->core->login(
    login=> $self->param('login'), 
    password=> $self->param('password'), 
    on_success=>sub {
      my $uid=shift;
      $self->session('uid' => $uid);
      $self->session('login' => $self->param('login'));
      $self->redirect_to('/setup');
    }, 
    on_error =>sub {
      $self->render(message=>'Invalid username/password.');
    });
}

=head2 register

See L</login>.

=cut

sub register {
  my $self=shift;
  my $admin=0;

  if($self->session('uid')) {
    $self->logf(debug => '[reg] Already logged in') if DEBUG;
    $self->redirect_to('/setup');
    return;
  }

  $self->render_later;
  Mojo::IOLoop->delay(sub {
    my $delay=shift;
    $self->redis->get('user:uids',$delay->begin);
  },
  sub { # Check invitation unless first user, or make admin.
    my ($delay,$uids)=@_;
    $self->logf(debug => '[reg] Got uids %s', $uids) if DEBUG;

    if($self->_got_invalid_register_params($uids)) {
      $self->logf(debug => '[reg] Failed %s', $self->stash('errors')) if DEBUG;
      $self->render;
      return;
    }

    if($uids) {
      $self->redis->get('user:'.$self->param('login').':uid',$delay->begin);
    }
    else {
      $admin++;
      $self->logf(debug => '[reg] First login == admin') if DEBUG;
      $delay->begin->();
    }
  }, sub {  # Get uid unless user exists
    my ($delay,$uid)=@_;
    if($uid) {
      $self->stash('errors')->{login} = 'Username is taken.';
      $self->render;
    }
    else {
      $self->redis->incr('user:uids',$delay->begin);
    }
  }, sub { # Create user
    my ($delay,$uid)=@_;
    my $digest = crypt $self->param('password'), join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    $self->logf(debug => '[reg] New user uid=%s, login=%s', $uid, $self->param('login')) if DEBUG;
    $self->session(uid=>$uid,login => $self->param('login'));
    $self->redis->execute(
      [ set => 'user:'.$self->param('login').':uid', $uid ],
      [ set => 'user:'.$self->param('login').':digest', $digest ],
      $delay->begin,
    );
  }, sub {
    my ($delay)=@_;
    $self->redirect_to('/setup');
  });
}

sub _got_invalid_register_params {
  my($self, $secret_required) = @_;
  my $errors = $self->stash('errors');
  my $email = $self->param('email') || '';
  my @passwords = $self->param('password');

  if($secret_required) {
    my $secret = $self->param('secret') || 'some-weird-secret-which-should-never-be-generated';
    $self->logf(debug => '[reg] Validating invite code %s', $secret) if DEBUG;
    if($secret ne crypt $email.$self->app->secret, $secret) {
      $self->logf(debug => '[reg] Invalid invite code.') if DEBUG;
      $self->stash(message => 'Invalid invite code.');
      return 1;
    }
  }

  if(($self->param('login') || '') !~ m/^[\w]{4,15}$/) {
    $errors->{login} = 'Username must consist of letters and numbers and be 4-15 characters long';
  }
  if($self->param('email') !~ m/.\@./) {
    $errors->{email} = 'Invalid email.';
  }

  if(2 != grep { $_ } @passwords or $passwords[0] ne $passwords[1]) {
    $errors->{password} = 'You need to enter the same password twice.';
  }
  elsif(6 < length $passwords[0]) {
    $errors->{password} = 'The password must be at least 6 characters long';
  }

  return keys %$errors;
}

sub logout {
  my $self=shift;
  $self->session(uid=>undef,login=>undef);
  $self->redirect_to('/');
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
