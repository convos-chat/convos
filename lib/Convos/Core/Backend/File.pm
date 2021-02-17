package Convos::Core::Backend::File;
use Mojo::Base 'Convos::Core::Backend';

use Convos::Date qw(dt);
use Convos::Util qw(DEBUG);
use Fcntl qw(:flock);
use File::ReadBackwards;
use Mojo::File;
use Mojo::JSON qw(false true);
use Mojo::Util qw(encode decode);
use Symbol;
use Time::Seconds;

use constant FLAG_OFFSET    => 48;    # chr 48 == "0"
use constant FLAG_NONE      => 0;
use constant FLAG_HIGHLIGHT => 1;
use constant FLAG_PREFORMAT => 2;
use constant FLAG_Y         => 4;     # not yet in use
use constant FLAG_Z         => 8;     # not yet in use

my %FORMAT = (
  action      => ['* %s %s',                   qw(from message)],
  kick        => ['-!- %s kicked %s. %s',      qw(kicker part message)],
  nick_change => ['-!- %s changed nick to %s', qw(nick new_nick)],
  notice      => ['-%s- %s',                   qw(from message)],
  part        => ['-!- %s parted. %s',         qw(nick message)],
  private     => ['<%s> %s',                   qw(from message)],
  preformat   => ['<%s> %s',                   qw(from message)],
);

has home => sub { Carp::confess('home() cannot be built') };

sub connections_p {
  my ($self, $user) = @_;
  my $user_dir = $self->home->child(@{$user->uri})->dirname;

  return Mojo::Promise->reject($!) unless opendir(my ($CONNECTIONS), $user_dir);

  my @connections;
  while (my $id = readdir $CONNECTIONS) {
    next unless $id =~ /^\w+/;
    my $settings = $user_dir->child($id, 'connection.json');
    next unless -e $settings;
    push @connections, Mojo::JSON::decode_json($settings->slurp);
    delete $connections[-1]{state};    # should not be stored in connection.json
  }

  return Mojo::Promise->resolve(\@connections);
}

sub delete_messages_p {
  my ($self, $obj) = @_;
  return Mojo::Promise->reject('Unknown target.') unless $obj and $obj->connection;
  return Mojo::IOLoop->subprocess->run_p(sub { $self->_delete_messages($obj) })->then(sub {$obj});
}

sub delete_object_p {
  my ($self, $obj) = @_;

  if ($obj->isa('Convos::Core::Connection')) {
    $obj->unsubscribe($_) for qw(conversation message state);
  }

  return Mojo::IOLoop->subprocess->run_p(sub { $self->_delete_object($obj) })->then(sub {$obj});
}

sub load_object_p {
  my ($self, $obj) = @_;
  my $data = {};

  my $storage_file = $self->home->child(@{$obj->uri});
  if (-e $storage_file) {
    eval { $data = Mojo::JSON::decode_json($storage_file->slurp); };
    return Mojo::Promise->reject($@ || 'Unknown error.') unless $data;
  }

  return Mojo::Promise->resolve($data);
}

sub messages_p {
  my ($self, $obj, $query) = @_;

  if ($query->{around}) {
    my %query_before = (%$query, around => undef, before => $query->{around});
    my %query_after  = (%$query, around => undef, after  => $query->{around}, include => 1);

    warn sprintf "[%s] Getting messages around %s\n", $obj->id, $query->{around} if DEBUG;

    return Mojo::Promise->all(
      $self->messages_p($obj, \%query_before),
      $self->messages_p($obj, \%query_after),
    )->then(sub {
      my ($before, $after) = map { $_->[0] } @_;
      return {%$before, %$after, messages => [map { @{$_->{messages}} } ($before, $after)]};
    });
  }

  my %args;
  $args{re} = join '.*', map { $_ = quotemeta $_; /"(.+)\\"/ ? "\\b$1\\b" : $_ } split /\s+/,
    $query->{match} // '';
  $args{re}       = qr/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}) \s (\d?) \s* (.*$args{re}.*)$/ix;
  $args{from}     = $query->{from} if $query->{from};
  $args{include}  = $query->{include} || 0;
  $args{limit}    = $query->{limit}   || 60;
  $args{messages} = [];

  # If both "before" and "after" are provided
  if ($query->{before} and $query->{after}) {
    $args{before}            = dt $query->{before};
    $args{after}             = dt $query->{after};
    @args{qw(cursor inc_by)} = ($args{after}, 1);
  }

  # If "before" is provided but not "after"
  # Set "after" to 12 months before "before"
  elsif ($query->{before} and !$query->{after}) {
    $args{before}            = dt $query->{before};
    $args{after}             = $args{before}->add_months(-12);
    @args{qw(cursor inc_by)} = ($args{before}, -1);
  }

  # If "after" is provided but not "before"
  # Set "before" to 12 months after "after"
  elsif (!$query->{before} and $query->{after}) {
    my $future = dt->inc_month(1);
    $args{after}             = dt $query->{after};
    $args{before}            = $args{after}->add_months(12);
    $args{before}            = $future if $args{before} > $future;
    @args{qw(cursor inc_by)} = ($args{after}, 1);
  }

  # If neither "before" nor "after" are provided
  # Set "before" to now and "after" to 12 months before "before"
  else {
    $args{before}            = 10 + dt;    # make sure we get the message sent right now as well
    $args{after}             = $args{before}->add_months(-12);
    @args{qw(cursor inc_by)} = ($args{before}, -1);
  }

  # Do not search if the difference between "before" and "after" is more than 12 months
  # This limits the amount of time that could be spent searching and it also prevents DoS attacks
  return Mojo::Promise->reject('"after" must be before "before".') if $args{after} > $args{before};
  return Mojo::Promise->reject('"before" - "after" is longer than 12 months.')
    if $args{before} - $args{after} > $args{before} - $args{before}->add_months(-12);

  warn sprintf "[%s] Getting messages from %s to %s (i=%s, l=%s, c=%s)\n", $obj->id,
    $args{after}->datetime, $args{before}->datetime, @args{qw(inc_by limit)},
    $args{cursor}->datetime,
    if DEBUG;

  return Mojo::IOLoop->subprocess->run_p(
    sub { $self->_messages_response($self->_messages($obj, \%args)) });
}

sub notifications_p {
  my ($self, $user, $query) = @_;
  $query->{limit} ||= 40;

  my ($file, $FH) = ($self->_notifications_file($user));
  unless ($FH = File::ReadBackwards->new($file)) {
    warn "[@{[$user->id]}] Read $file: $!\n" if DEBUG >= 3;
    return Mojo::Promise->resolve({messages => []});
  }

  my ($re, @notifications) = qr/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}) (\S+) (\S+) (.*)$/;
  warn "[@{[$user->id]}] Gettings notifications from $file...\n" if DEBUG;
  while (my $line = $FH->getline) {
    $line = decode 'UTF-8', $line;
    next unless $line =~ $re;
    my $message = {connection_id => $2, conversation_id => $3, message => $4, ts => $1};
    my $ts      = dt $message->{ts};
    $self->_message_type_from($message);
    unshift @notifications, $message;
    last if @notifications == $query->{limit};
  }

  return Mojo::Promise->resolve({messages => \@notifications});
}

sub save_object_p {
  my ($self, $obj) = @_;
  my $storage_file = $self->home->child(@{$obj->uri});
  my $swap_file    = $storage_file->sibling(sprintf '.%s.swap', $storage_file->basename);

  my $p = Mojo::Promise->new;
  eval {
    my $dir = $storage_file->dirname;
    $dir->make_path($dir) unless -d $dir;
    $swap_file->spurt(Mojo::JSON::encode_json($obj->TO_JSON('private')));
    die "Failed to write $swap_file" unless -s $swap_file;
    $swap_file->move_to($storage_file);
    warn "[@{[$obj->id]}] Save success. ($storage_file)\n" if DEBUG;
    $p->resolve($obj);
  } or do {
    warn "[@{[$obj->id]}] Save $@ ($storage_file)\n" if DEBUG;
    $p->reject($@ || 'Unknown error.');
  };

  return $p;
}

sub users_p {
  my $self = shift;
  my $home = $self->home;
  my @users;

  if (opendir(my $USERS, $home)) {
    while (my $email = readdir $USERS) {
      my $settings = $home->child($email, 'user.json');
      next unless $email =~ /.\@./ and -e $settings;    # poor mans regex
      push @users, Mojo::JSON::decode_json($settings->slurp);
      $users[-1]{registered} ||= Mojo::Date->new($settings->stat->ctime)->to_datetime;
    }
  }

  # Return users in a predictable order
  @users = sort { $a->{registered} cmp $b->{registered} || $a->{email} cmp $b->{email} } @users;

  return Mojo::Promise->resolve(\@users);
}

sub _add_notification {
  my ($self, $obj, $ts, $message) = @_;
  my $file = $self->_notifications_file($obj->connection->user);
  my $t    = dt $ts;

  open my $FH, '>>', $file or die "Can't open notifications file $file: $!";
  warn "[@{[$obj->id]}] $file <<< ($message)\n" if DEBUG >= 3;
  flock $FH, LOCK_EX;
  printf $FH "%s %s %s %s\n", $t->datetime, $obj->connection->id, $obj->id, $message;
  flock $FH, LOCK_UN;
}

sub _delete_messages {
  my ($self, $obj) = @_;
  my $basename = sprintf '%s.log', $obj->id;
  $self->home->child($obj->connection->user->id, $obj->connection->id)->list_tree->each(sub {
    $_[0]->remove if $_[0]->basename eq $basename;
  });
}

sub _delete_object {
  my ($self, $obj) = @_;
  my $path = $self->home->child(@{$obj->uri});

  if (grep { $obj->isa($_) } qw(Convos::Core::Connection Convos::Core::User)) {
    $path = $path->dirname;
  }

  if (-d $path) {
    $path->remove_tree({verbose => DEBUG});
  }
  else {
    unlink $path or die "unlink $path: $!";
  }
}

sub _format {
  my ($self, $type) = @_;
  my $format = $FORMAT{$type};
  return @$format                                                    if $format;
  warn "[Convos::Core::Backend::File] No format defined for $type\n" if $type ne 'error' and DEBUG;
  return;
}

sub _log {
  my ($self, $obj, $ts, $message) = @_;
  my $t    = dt $ts;
  my $ym   = sprintf '%s/%02s', $t->year, $t->mon;
  my $file = $self->_log_file($obj, $ym);
  my $dir  = $file->dirname;

  $message = encode 'UTF-8', $message if utf8::is_utf8($message);

  $dir->make_path unless -d $dir;
  open my $FH, '>>', $file or die "Can't open log file $file: $!";
  warn "[@{[$obj->id]}:@{[$t->datetime]}] $file <<< ($message)\n" if DEBUG >= 3;
  flock $FH, LOCK_EX;
  $FH->syswrite($t->datetime . " $message\n") or die "Write $file: $!";
  flock $FH, LOCK_UN;
}

sub _log_file {
  my ($self, $obj, $t) = @_;
  my @path = ($obj->connection->user->id, $obj->connection->id);

  push @path, ref $t ? sprintf '%s/%02s', $t->year, $t->mon : $t;

  if (my $id = $obj->id) {
    $id =~ s!/!%2F!g;
    push @path, $id;
  }

  my $leaf = pop @path;
  return $self->home->child(@path, "$leaf.log");
}

sub _message_type_from {
  my ($self, $message) = @_;
  return @$message{qw(type from)} = (private => $1) if $message->{message} =~ s/^<([^\s\>]+)>\s//;
  return @$message{qw(type from)} = (notice  => $1) if $message->{message} =~ s/^-([^\s\>]+)-\s//;
  return @$message{qw(type from)} = (action  => $1) if $message->{message} =~ s/^\* (\S+)\s//;
  return @$message{qw(type from)} = (server  => '') if $message->{message} =~ s/^(?:-!-\s)?//;
  return @$message{qw(type from)} = (unknown => '');
}

# blocking method
sub _messages {
  my ($self, $obj, $args) = @_;
  my $cursor = $args->{cursor};

  # Check if the interval has been exhausted
  return $args if $cursor < $args->{after} || $cursor > $args->{before}->add_months(1);

  # Prepare cursor for next time _messages() will be called
  $args->{cursor} = $args->{cursor}->inc_month($args->{inc_by});

  my $FH;
  eval {
    my $file = $self->_log_file($obj, $cursor);
    $FH = $args->{inc_by} > 0 ? _open($file) : File::ReadBackwards->new($file);
    die qq{Can't read "$file": $!\n} unless $FH;
    warn "[@{[$obj->id]}] Reading $file\n" if DEBUG;
    1;
  } or do {
    warn "[@{[$obj->id]}] $@" if DEBUG >= 2;
    return $self->_messages($obj, $args);
  };

  while (my $line = $FH->getline) {
    $line = decode 'UTF-8', $line;
    next unless $line =~ $args->{re};

    my $flag    = $2 || '0';
    my $message = {message => $3, ts => $1};
    my $ts      = dt $message->{ts};

    # my $x       = $ts >= $args->{before} || $ts <= $args->{after} ? '-' : '+';
    # Test::More::note("($x) $args->{after} <> $1 <> $args->{before} - $3\n");
    # Not within time boundaries
    next if !$args->{include} and ($ts >= $args->{before} or $ts <= $args->{after});
    next if $args->{include}  and ($ts > $args->{before}  or $ts < $args->{after});

    # Found message
    $self->_message_type_from($message);
    next if $args->{from} and lc $message->{from} ne lc $args->{from};

    $message->{highlight} = (ord($flag) - FLAG_OFFSET) & FLAG_HIGHLIGHT ? true : false;
    $message->{type}      = 'preformat' if +(ord($flag) - FLAG_OFFSET) & FLAG_PREFORMAT;

    $args->{inc_by} < 0 ? unshift @{$args->{messages}}, $message : push @{$args->{messages}},
      $message;

    # Get more messages
    next unless @{$args->{messages}} > $args->{limit};

    # Got enough messages
    return $args;
  }

  return $self->_messages($obj, $args);
}

sub _messages_response {
  my ($self, $args) = @_;
  delete $args->{$_} for qw(after before);

  if (@{$args->{messages}} > $args->{limit}) {
    if ($args->{inc_by} > 0) {
      pop @{$args->{messages}};
      $args->{after} = $args->{messages}[-1]{ts};
    }
    else {
      shift @{$args->{messages}};
      $args->{before} = $args->{messages}[0]{ts};
    }
  }

  delete $args->{$_} for qw(cursor inc_by include limit match re);
  return $args;
}

sub _notifications_file {
  $_[0]->home->child($_[1]->id, 'notifications.log');
}

sub _open {
  return undef unless open my $FH, '<', shift;
  return $FH;
}

sub _setup {
  my $self = shift;

  Scalar::Util::weaken($self);
  $self->on(
    connection => sub {
      my ($self, $connection) = @_;
      my $cid = $connection->id;
      my $uid = $connection->user->id;

      Scalar::Util::weaken($self);
      $connection->on(
        message => sub {
          my ($connection, $target, $msg) = @_;
          my ($format, @keys) = $self->_format($msg->{type}) or return;
          my $message = sprintf $format, map { $msg->{$_} } @keys;
          my $flag    = FLAG_NONE;

          if ($msg->{highlight} and $target->id and !$target->is_private) {
            $self->_add_notification($target, $msg->{ts}, $message);
            $connection->user->save_p;
            $flag |= FLAG_HIGHLIGHT;
          }
          if ($msg->{type} eq 'preformat') {
            $flag |= FLAG_PREFORMAT;
          }

          $message = sprintf "%c %s", $flag + FLAG_OFFSET, $message;
          $self->_log($target, $msg->{ts}, $message);
        }
      );
    }
  );

  return $self->SUPER::_setup;
}

1;

=encoding utf8

=head1 NAME

Convos::Core::Backend::File - Backend for storing object to file

=head1 DESCRIPTION

L<Convos::Core::Backend::File> contains methods which is useful for objects
that want to be persisted to disk or store state to disk.

=head2 Where is data stored

C<CONVOS_HOME> can be set to specify the root location for where to save
data from objects. The default directory on *nix systems is something like this:

  $HOME/.local/share/convos/

C<$HOME> is figured out from L<File::HomeDir/my_home>.

=head2 Directory structure

  $CONVOS_HOME/
  $CONVOS_HOME/joe@example.com/                                 # one directory per user
  $CONVOS_HOME/joe@example.com/user.json                        # user settings
  $CONVOS_HOME/joe@example.com/irc-freenode/connection.json     # connection settings
  $CONVOS_HOME/joe@example.com/irc-freenode/2015/02.log         # connection log
  $CONVOS_HOME/joe@example.com/irc-freenode/2015/10/marcus.log  # conversation log
  $CONVOS_HOME/joe@example.com/irc-freenode/2015/12/#convos.log # conversation log

Notes about the structure:

=over 2

=item * Easy to delete a user and all associated data.

=item * Easy to delete a connection and all associated data.

=item * One log file per month should not cause too big files.

=item * Hard to delete a conversation thread. Ex: all conversations with "marcus".

=item * Hard to search for messages between connections for a given date.

=back

=head1 ATTRIBUTES

L<Convos::Core::Backend::File> inherits all attributes from
L<Convos::Core::Backend> and implements the following new ones.

=head2 home

See L<Convos::Core/home>.

=head1 METHODS

L<Convos::Core::Backend::File> inherits all methods from
L<Convos::Core::Backend> and implements the following new ones.

=head2 connections_p

See L<Convos::Core::Backend/connections_p>.

=head2 delete_messages_p

See L<Convos::Core::Backend/delete_messages_p>.

=head2 delete_object_p

See L<Convos::Core::Backend/delete_object_p>.

=head2 load_object_p

See L<Convos::Core::Backend/load_object_p>.

=head2 messages_p

See L<Convos::Core::Backend/messages_p>.

=head2 notifications_p

See L<Convos::Core::Backend/notifications_p>.

=head2 save_object_p

See L<Convos::Core::Backend/save_object_p>.

=head2 users_p

See L<Convos::Core::Backend/users_p>.

=head1 SEE ALSO

L<Convos::Core>.

=cut
