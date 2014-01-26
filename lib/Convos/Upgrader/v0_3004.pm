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
  my ($self, $cb) = @_;
  my $redis = $self->redis;

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->redis->smembers(connections => $delay->begin);
    },
    sub {
      my ($delay, $connections) = @_;
      my (%connections, %users);

      $redis->del('connections', $delay->begin);

      for my $name (@$connections) {
        my ($user, $old) = split /:/, $name;
        my $new = $self->_convert_connection_name($old);

        unless ($users{$user}++) {
          $redis->del("user:$user:connections", $delay->begin);
          $redis->sadd("users", $user, $delay->begin);
          $self->_set_avatar_for_user($user, $delay);
        }

        $connections{$old} = $new;
        $self->_convert_connection_for_user($user, $old, $new, $delay);
      }

      for my $user (keys %users) {
        $self->_convert_conversations_for_user($user, \%connections, $delay);
      }
    },
    sub {
      my ($delay) = @_;
      $self->$cb('');
    },
  );
}

sub _convert_connection_name {
  my ($self, $name) = @_;

  return 'linpro'   if $name eq 'irc.linpro.no';
  return 'magnet'   if $name eq 'irc.perl.org';
  return 'freenode' if $name eq 'irc.freenode.net';

  $name =~ s!^irc\.!!g;
  $name =~ s!\W!-!g;
  $name;
}

sub _convert_connection_for_user {
  my ($self, $user, $old, $new, $delay) = @_;
  my $redis = $self->redis;

  $redis->keys(
    "user:$user:connection:$old*",
    sub {
      my ($redis, $keys) = @_;

      for my $key_old (@$keys) {
        my $key_new = $key_old;
        $key_new =~ s/:$old\b/:$new/;
        $redis->rename($key_old, $key_new, $delay->begin) if $key_old ne $key_new;
      }
    }
  );

  $redis->sadd(connections              => "$user:$new", $delay->begin);
  $redis->sadd("user:$user:connections" => $new,         $delay->begin);
}

sub _convert_conversations_for_user {
  my ($self, $user, $map, $delay) = @_;
  my $redis = $self->redis;

  $redis->zrange(
    "user:$user:conversations",
    0, -1,
    'WITHSCORES' => sub {
      my ($redis, $conversations) = @_;

      $redis->del("user:$user:conversations", $delay->begin);

      while (@$conversations) {
        my (@name) = id_as shift @$conversations;
        my $score = shift @$conversations or last;
        $name[0] = $map->{$name[0]} or next;
        $redis->zadd("user:$user:conversations", $score, as_id(@name), $delay->begin);
      }
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
