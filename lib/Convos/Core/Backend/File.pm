package Convos::Core::Backend::File;
use Mojo::Base 'Convos::Core::Backend';

use Convos::Util qw(next_tick spurt DEBUG);
use Fcntl ':flock';
use File::Path ();
use File::ReadBackwards;
use File::Spec::Functions 'catfile';
use Mojo::IOLoop::ForkCall ();
use Mojo::JSON;
use Symbol;
use Time::Piece;
use Time::Seconds;

use constant FLAG_OFFSET    => 48;    # chr 48 == "0"
use constant FLAG_NONE      => 0;
use constant FLAG_HIGHLIGHT => 1;
use constant FLAG_X         => 2;     # not yet in use
use constant FLAG_Y         => 4;     # not yet in use
use constant FLAG_Z         => 8;     # not yet in use

my %FORMAT = (
  action      => ['* %s %s',                   qw(from message)],
  kick        => ['-!- %s kicked %s. %s',      qw(kicker part message)],
  nick_change => ['-!- %s changed nick to %s', qw(nick new_nick)],
  notice      => ['-%s- %s',                   qw(from message)],
  part        => ['-!- %s parted. %s',         qw(nick message)],
  private     => ['<%s> %s',                   qw(from message)],
);

has home => sub { Carp::confess('home() cannot be built') };

has _fc => sub {
  my $fc = Mojo::IOLoop::ForkCall->new;
  $fc->on(error => sub { warn "[fc] $_[1]" });
  $fc;
};

sub connections {
  my ($self, $user, $cb) = @_;
  my $user_dir = $self->home->rel_dir($user->email);
  my ($CONNECTIONS, @connections);

  unless (opendir $CONNECTIONS, $user_dir) {
    die $! unless $cb;
    return next_tick $self, $cb, $!, [];
  }

  while (my $id = readdir $CONNECTIONS) {
    next unless $id =~ /^\w+/;
    my $settings = catfile $user_dir, $id, 'connection.json';
    next unless -e $settings;
    push @connections, Mojo::JSON::decode_json(Mojo::Util::slurp($settings));
  }

  return \@connections unless $cb;
  return next_tick $self, $cb, '', \@connections;
}

sub delete_object {
  my ($self, $obj, $cb) = @_;
  my $method = $obj->isa('Convos::Core::User') ? '_delete_user' : '_delete_connection';

  Mojo::IOLoop->delay(
    sub {
      $self->_fc->run(sub { $self->$method($obj) }, shift->begin);
    },
    sub {
      my ($delay, $err) = @_;
      warn "[@{[$obj->id]}] Delete object: @{[$err || 'Success']}\n" if DEBUG;
      $self->$cb($err || '');
    },
  );

  return $self;
}

sub load_object {
  my ($self, $obj, $cb) = @_;
  my $storage_file = $self->_settings_file($obj);
  my $data;

  -e $storage_file and eval {
    $data = Mojo::JSON::decode_json(Mojo::Util::slurp($storage_file));
    return $data unless $cb;
    return next_tick $obj, $cb, '', $data;
  };

  return next_tick $obj, $cb, $@, {} if $cb;
  return $data unless $@;
  die $@;
}

sub messages {
  my ($self, $obj, $query, $cb) = @_;
  my $re = $query->{match} || qr{.};
  my %args;

  $re = qr{\Q$re\E}i unless ref $re;
  $re = qr/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}) (\d?)\s*(.*$re.*)$/;

  $args{limit}    = $query->{limit} || 60;
  $args{messages} = [];
  $args{re}       = $re;

  # If both "before" and "after" are provided
  if ($query->{before} and $query->{after}) {
    $args{before} = _strptime($query->{before}, '%Y-%m-%dT%H:%M:%S');
    $args{after}  = _strptime($query->{after},  '%Y-%m-%dT%H:%M:%S');
  }

  # If "before" is provided but not "after"
  # Set "after" to 12 months before "before"
  elsif ($query->{before} and !$query->{after}) {
    $args{before} = _strptime($query->{before}, '%Y-%m-%dT%H:%M:%S');
    $args{after} = $args{before}->add_months(-12);
  }

  # If "after" is provided but not "before"
  # Set "before" to 12 months after "after"
  elsif (!$query->{before} and $query->{after}) {
    $args{after} = _strptime($query->{after}, '%Y-%m-%dT%H:%M:%S');
    $args{before} = $args{after}->add_months(12);
  }

  # If neither "before" nor "after" are provided
  # Set "before" to now and "after" to 12 months before "before"
  else {
    $args{before} = 60 + gmtime;    # make sure we get the message sent right now as well
    $args{after} = $args{before}->add_months(-12);
  }

  # Do not search if the difference between "before" and "after" is more than 12 months
  # This limits the amount of time that could be spent searching and it also prevents DoS attacks
  return $self if $args{before} - $args{after} > $args{before} - $args{before}->add_months(-12);

  # The {cursor} is used to walk through the month-hashed log files
  $args{cursor} = $args{before};

  warn "[@{[$obj->id]}] Searching $args{after} - $args{before}\n" if DEBUG;
  Mojo::IOLoop->delay(
    sub {
      $self->_fc->run(sub { $self->_messages($obj, \%args) }, shift->begin);
    },
    sub {
      my ($delay, $err, $messages) = @_;
      $self->$cb($err, $messages || []);
    },
  );

  return $self;
}

sub notifications {
  my ($self, $user, $query, $cb) = @_;
  my $file = $self->_notifications_file($user);
  my ($FH, $re, @notifications);

  $query->{limit} ||= 40;

  unless ($FH = File::ReadBackwards->new($file)) {
    warn "[@{[$user->id]}] Read $file: $!\n" if DEBUG;
    return next_tick $self, $cb, '', [];
  }

  $re = $query->{match} || qr{.};
  $re = qr{\Q$re\E}i unless ref $re;
  $re = qr/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}) (\S+) (\S+) (.*$re.*)$/;

  warn "[@{[$user->id]}] Gettings notifications from $file...\n" if DEBUG;
  while (my $line = $FH->getline) {
    next unless $line =~ $re;
    my $message = {connection_id => $2, dialog_id => $3, message => $4, ts => $1};
    my $ts = _strptime($message->{ts}, '%Y-%m-%dT%H:%M:%S');
    $self->_message_type_from($message);
    unshift @notifications, $message;
    last if @notifications == $query->{limit};
  }

  return next_tick $self, $cb, '', \@notifications;
}

sub save_object {
  my ($self, $obj, $cb) = @_;
  my $storage_file = $self->_settings_file($obj);

  $cb ||= sub { die $_[1] if $_[1] };

  eval {
    my $dir = File::Basename::dirname($storage_file);
    File::Path::make_path($dir) unless -d $dir;
    spurt(Mojo::JSON::encode_json($obj->TO_JSON('private')), $storage_file);
    warn "[@{[$obj->id]}] Save success. ($storage_file)\n" if DEBUG;
    return next_tick $obj, $cb, '';
  };

  my $err = $@;
  warn "[@{[$obj->id]}] Save $err ($storage_file)\n" if DEBUG;
  return next_tick $obj, $cb, $err;
}

sub users {
  my ($self, $cb) = @_;
  my $home = $self->home;
  my @users;

  if (opendir(my $USERS, $home)) {
    while (my $email = readdir $USERS) {
      my $settings = $home->rel_file("$email/user.json");
      next unless $email =~ /.\@./ and -e $settings;    # poor mans regex
      push @users, Mojo::JSON::decode_json(Mojo::Util::slurp($settings));
    }
  }

  return \@users unless $cb;
  return next_tick $self, $cb, '', \@users;
}

sub _delete_connection {
  my ($self, $connection) = @_;
  my $path = $self->home->rel_dir(join('/', $connection->user->email, $connection->id));
  $connection->unsubscribe($_) for qw(dialog message state);
  File::Path::remove_tree($path, {verbose => DEBUG}) if -d $path;
}

sub _delete_user {
  my ($self, $user) = @_;
  my $path = $self->home->rel_dir($user->user->email);
  File::Path::remove_tree($path, {verbose => DEBUG}) if -d $path;
}

sub _format {
  my ($self, $key) = @_;
  my $format = $FORMAT{$key};
  return @$format if $format;
  warn "[Convos::Core::Backend::File] No format defined for $key\n" if DEBUG;
  return;
}

sub _log {
  my ($self, $obj, $ts, $message) = @_;
  my $t    = gmtime $ts;
  my $ym   = sprintf '%s/%02s', $t->year, $t->mon;
  my $file = $self->_log_file($obj, $ym);
  my $dir  = File::Basename::dirname($file);

  $message = Mojo::Util::encode('UTF-8', $message) if utf8::is_utf8($message);

  File::Path::make_path($dir) unless -d $dir;
  open my $FH, '>>', $file or die "Can't open log file $file: $!";
  warn "[@{[$obj->id]}:@{[$t->datetime]}] $file <<< ($message)\n" if DEBUG == 2;
  flock $FH, LOCK_EX;
  $FH->syswrite($t->datetime . " $message\n") or die "Write $file: $!";
  flock $FH, LOCK_UN;
}

sub _log_file {
  my ($self, $obj, $t) = @_;
  my @path = ($obj->connection->user->id, $obj->connection->id);

  push @path, ref $t ? sprintf '%s/%02s', $t->year, $t->mon : $t;
  push @path, $obj->id if $obj->id;

  return $self->home->rel_file(join('/', @path) . '.log');
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

  return [] if $args->{after} > $args->{before};
  return $args->{messages} if $cursor < $args->{after};
  $args->{cursor} = $args->{cursor}->add_months(-1) while $cursor->mon == $args->{cursor}->mon;

  my $file = $self->_log_file($obj, $cursor);
  my $FH = File::ReadBackwards->new($file);
  unless ($FH) {
    warn "[@{[$obj->id]}] $!: $file\n" if DEBUG >= 2;
    return $self->_messages($obj, $args);
  }

  warn "[@{[$obj->id]}] Gettings messages from $file...\n" if DEBUG;
  while (my $line = $FH->getline) {
    $line = Mojo::Util::decode('UTF-8', $line);
    next unless $line =~ $args->{re};
    my $flag = $2 || '0';
    my $message = {message => $3, ts => $1};
    my $ts = _strptime($message->{ts}, '%Y-%m-%dT%H:%M:%S');
    next unless $ts < $args->{before} and $ts > $args->{after};
    $self->_message_type_from($message);
    $message->{highlight}
      = (ord($flag) - FLAG_OFFSET) & FLAG_HIGHLIGHT ? Mojo::JSON->true : Mojo::JSON->false;
    unshift @{$args->{messages}}, $message;
    return $args->{messages} if int @{$args->{messages}} == $args->{limit};
  }

  return $self->_messages($obj, $args);
}

sub _notifications_file {
  $_[0]->home->rel_file(join '/', $_[1]->id, 'notifications.log');
}

sub _save_notification {
  my ($self, $obj, $ts, $message) = @_;
  my $file = $self->_notifications_file($obj->connection->user);
  my $t    = gmtime $ts;

  open my $FH, '>>', $file or die "Can't open notifications file $file: $!";
  warn "[@{[$obj->id]}] $file <<< ($message)\n" if DEBUG == 2;
  flock $FH, LOCK_EX;
  printf $FH "%s %s %s %s\n", $t->datetime, $obj->connection->id, $obj->id, $message;
  flock $FH, LOCK_UN;
}

sub _settings_file {
  my ($self, $obj) = @_;

  if ($obj->isa('Convos::Core::Connection')) {
    return $self->home->rel_file(sprintf '%s/%s/connection.json', $obj->user->email, $obj->id);
  }
  elsif ($obj->isa('Convos::Core::User')) {
    return $self->home->rel_file(sprintf '%s/user.json', $obj->email);
  }
  elsif (ref($obj) =~ /::(\w+)$/) {
    return $self->home->rel_file('%s.json', lc $1);
  }

  die "Cannot figure out path to settings file for $obj";
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
          my $flag = FLAG_NONE;

          if ($msg->{highlight} and $target->id and !$target->is_private) {
            $self->_save_notification($target, $msg->{ts}, $message);
            $connection->user->{unread}++;
            $connection->user->save;
            $flag |= FLAG_HIGHLIGHT;
          }

          $self->emit("user:$uid",
            message => {connection_id => $cid, dialog_id => $target->id, %$msg});
          $message = sprintf "%c %s", $flag + FLAG_OFFSET, $message;
          $self->_log($target, $msg->{ts}, $message);
        }
      );
      $connection->on(
        state => sub {
          my ($connection, $type, $args) = @_;
          $self->emit("user:$uid", state => {connection_id => $cid, %$args, type => $type});
        }
      );
    }
  );
}

sub _strptime {
  local $_ = shift;
  $_ =~ s!\.?0*Z$!!;
  Time::Piece->strptime($_, '%Y-%m-%dT%H:%M:%S');
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
  $CONVOS_HOME/joe@example.com/irc-freenode/2015/10/marcus.log  # dialog log
  $CONVOS_HOME/joe@example.com/irc-freenode/2015/12/#convos.log # dialog log

Notes about the structure:

=over 2

=item * Easy to delete a user and all associated data.

=item * Easy to delete a connection and all associated data.

=item * One log file per month should not cause too big files.

=item * Hard to delete a dialog thread. Ex: all dialogs with "marcus".

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

=head2 connections

See L<Convos::Core::Backend/connections>.

=head2 delete_object

See L<Convos::Core::Backend/delete_object>.

=head2 load_object

See L<Convos::Core::Backend/load_object>.

=head2 messages

See L<Convos::Core::Backend/messages>.

=head2 notifications

See L<Convos::Core::Backend/notifications>.

=head2 save_object

See L<Convos::Core::Backend/save_object>.

=head2 users

See L<Convos::Core::Backend/users>.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
