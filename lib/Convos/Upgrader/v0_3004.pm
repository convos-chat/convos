package Convos::Upgrader::v0_3004;

=head1 NAME

Convos::Upgrader::v0_3004 - Upgrade instructions to version 0.3004

=head1 DESCRIPTION

This upgrade step will convert the old connection scheme to a
network based scheme.

=cut

use Mojo::Base 'Convos::Upgrader';
use Convos::Core::Util qw( id_as as_id );

=head1 METHODS

=head2 run

Called by L<Convos::Upgrader>.

=cut

sub run {
  my $self  = shift;
  my $delay = $self->redis->ioloop->delay;
  my $guard = $delay->begin;

  $self->_convert_connections($delay);
  $delay->on(finish => sub { $self->emit('finish'); });
  $guard->();    # make sure finish is triggered
}

sub _convert_connections {
  my ($self, $delay) = @_;
  my $redis = $self->redis;
  my $guard = $delay->begin;

  $redis->smembers(
    users => sub {
      my ($redis, $users) = @_;

      for my $user (@$users) {
        $self->_convert_connections_for_user($user, $delay);
        $self->_set_avatar_for_user($user, $delay);
      }

      $guard->();
    }
  );
}

sub _convert_connection_name {
  my ($self, $name) = @_;

  return 'linpro'   if $name eq 'irc.linpro.no';
  return 'magnet'   if $name eq 'irc.perl.org';
  return 'freenode' if $name eq 'irc.freenode.org';

  $name =~ s!\W!-!g;
  $name;
}

sub _convert_connections_for_user {
  my ($self, $user, $delay) = @_;
  my $redis = $self->redis;
  my $guard = $delay->begin;

  $redis->smembers(
    "user:$user:connections" => sub {
      my ($redis, $connections) = @_;
      my %map;

      for my $name (@$connections) {
        my $old = $name;
        my $cb  = $delay->begin;

        $name = $self->_convert_connection_name($old);
        $map{$old} = $name;

        $redis->keys(
          "user:$user:connection:$old*",
          sub {
            my ($redis, $keys) = @_;

            for my $key_old (@$keys) {
              my $key_new = $key_old;
              $key_new =~ s/:$old\b/:$name/;
              $redis->rename($key_old, $key_new, $delay->begin);
            }

            $cb->();
          }
        );
      }

      $self->_convert_conversations_for_user($user, \%map, $delay);
      @$connections or return $guard->();
      $redis->del("user:$user:connections");
      $redis->sadd("user:$user:connections" => @$connections, $guard);
    }
  );
}

sub _convert_conversations_for_user {
  my ($self, $user, $map, $delay) = @_;
  my $redis = $self->redis;
  my $guard = $delay->begin;

  $redis->zrange(
    "user:$user:conversations",
    0, -1,
    'WITHSCORES' => sub {
      my ($redis, $conversations) = @_;

      $redis->del("user:$user:conversations", $guard);

      while (@$conversations) {
        my (@name) = id_as shift @$conversations;
        my $score = shift @$conversations or last;
        $name[0] = $map->{$name[0]} or next;
        $redis->zadd("user:$user:conversations", $score, as_id @name);
      }

      $guard->();
    }
  );
}

sub _set_avatar_for_user {
  my ($self, $user, $delay) = @_;
  my $cb = $delay->begin;

  $self->redis->hmget(
    "user:$user",
    "avatar", "email",
    sub {
      my ($redis, $data) = @_;
      return $cb->() if $data->[0];
      return $cb->() if !$data->[1];
      $redis->hset("user:$user", "avatar", $data->[1], $cb);
    }
  );
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
