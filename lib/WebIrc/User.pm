package WebIrc::User;

=head1 NAME

WebIrc::User - Mojolicious controller for user data

=cut

use Mojo::Base 'Mojolicious::Controller';

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
  Mojo::IOLoop->delay(sub {
    my $delay=shift;
    $self->redis->get('user:'.$self->param('login').':uid',$delay->begin);
    }, sub {
      my ($delay,$uid)=@_;
      return $self->render( message=>"Invalid username/password" ) unless  $uid && $uid =~ /\d+/;
      $self->stash(uid=>$uid);
      $self->redis->get('user:'.$self->param('login').':digest', $delay->begin);
    }, sub {
      my($delay,$digest)=@_;
      if(crypt($self->param('password'),$digest) eq $digest) {
        $self->session('uid' => $self->stash('uid'));
        $self->session('login' => $self->param('login'));
        $self->redirect_to('/setup');
      }
      else { $self->render(message=>'Invalid username/password.'); }
    });
}

=head2 register

See L</login>.

=cut

sub register {
  my $self=shift;

  unless($self->param('login') =~ m/^[\w]{4,15}$/) {
    return $self->render(message=>'Username must consist of letters and numbers and be 4-15 characters long');
  }
  if($self->param('password') and length $self->param('password') < 5){
    return $self->render('message'=>'The password must be at least 6 characters long');
  }
  my $admin=0;
  $self->render_later;
  Mojo::IOLoop->delay(sub {
    my $delay=shift;
    $self->redis->get('user:uids',$delay->begin);
  },
  sub { # Check invitation unless first user, or make admin.
    my ($delay,$uids)=@_;
    if($uids && ($self->param('secret')  ne 
      crypt($self->param('email').$self->app->secret,$self->param('secret')))) {
        return $self->render_not_found;
    }
    if($uids) {
      return $self->redis->get('user:'.$self->param('login').':uid',$delay->begin);
    }
    $admin++;
    $delay->begin->();
  }, sub {  # Get uid unless user exists
    my ($delay,$uid)=@_;
    return $self->render(message=>'This username is taken') if $uid;
    $self->redis->incr('user:uids',$delay->begin);
  }, sub { # Create user
    my ($delay,$uid)=@_;
    $self->redis->set('user:'.$self->param('login').':uid',$uid,$delay->begin);
    $self->redis->set('user:'.$self->param('login').':digest', crypt($self->param('password'),
          join('', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64])),$delay->begin);
      $self->session(uid=>$uid,login => $self->param('login'));
  }, sub {
    my ($delay)=@_;
    $self->redirect_to('/setup');
  });
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
