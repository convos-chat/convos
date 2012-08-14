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
  $self->redis->get('user:'.$self->param('login').':uid',$self->parallol(sub {
    my ($redis,$uid)=@_;
    warn("uid $uid");
    return $self->stash( message=>"Invalid username/password" ) unless  $uid && $uid =~ /\d+/;
    $redis->get('user:'.$self->param('login').':digest', $self->parallol(sub {
      my ($redis,$digest)=@_;
      warn "Testing $digest";
      if(crypt($self->param('password'),$digest) eq $digest) {
        $self->session('uid' => $uid);
        $self->redirect_to('/setup');
      }
      else { $self->stash(message=>'Invalid username/password.'); }
    }));
  }));
}

=head2 register

See L</login>.

=cut

sub register {
  my $self=shift;
  $self->render_later;
  if($self->param('login') =~ m/^[\w]{4,15}$/) {
    $self->redis->get('user:'.$self->param('login').':uid',$self->parallol(sub {
      my ($redis,$uid)=@_;
      unless($uid) {
        if($self->param('password') && length($self->param('password'))>5){
          $redis->incr('user:uids',$self->parallol(sub {
            my ($redis,$uid)=@_;
            $redis->set('user:'.$self->param('login').':uid',$uid);
            $redis->set('user:'.$self->param('login').':digest',
              crypt($self->param('password'),
                join('', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64])));
            $self->session(uid=>$uid);
            $self->redirect_to('/setup');
          }));
        }
        else {
          $self->stash('message'=>'The password must be at least 6 characters long');
        }
      }
      else {
        $self->stash(message=>'This username is taken');
      }
    }));
  }
  else {
    $self->stash(message=>'Username must consist of letters and numbers and be 4-15 characters long');
  }
}

=head1 COPYRIGHT

See L<WebIrc>.

=head1 AUTHOR

Jan Henning Thorsen

Marcus Ramberg

=cut

1;
