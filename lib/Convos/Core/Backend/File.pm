package Convos::Core::Backend::File;

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

=over 4

=item * Easy to delete a user and all associated data.

=item * Easy to delete a connection and all associated data.

=item * One log file per month should not cause too big files.

=item * Hard to delete a conversation thread. Ex: all conversations with "marcus".

=item * Hard to search for messages between connections for a given date.

=back

=cut

use Mojo::Base 'Convos::Core::Backend';
use Mojo::Home;
use Mojo::IOLoop::ForkCall ();
use Mojo::JSON;
use Cwd ();
use Fcntl ':flock';
use File::HomeDir ();
use File::Path    ();
use File::ReadBackwards;
use File::Spec::Functions qw( catdir catfile );
use Symbol;
use Time::Piece;
use Time::Seconds;
use constant DEBUG => $ENV{CONVOS_DEBUG} || 0;

# copy/paste from File::ReadBackwards
my $MAX_READ_SIZE = 1 << 13;

=head1 ATTRIBUTES

L<Convos::Core::Backend::File> inherits all attributes from
L<Convos::Core::Backend> and implements the following new ones.

=head2 home

Holds a L<Mojo::Home> object which points to the root directory where data
can be stored.

=cut

has home => sub { shift->_build_home };

=head1 METHODS

L<Convos::Core::Backend::File> inherits all methods from
L<Convos::Core::Backend> and implements the following new ones.

=head2 connections

See L<Convos::Core::Backend/connections>.

=cut

sub connections {
  my ($self, $user, $cb) = @_;
  my $user_dir = $self->home->rel_dir($user->email);
  my ($CONNECTIONS, @connections);

  unless (opendir $CONNECTIONS, $user_dir) {
    die $! unless $cb;
    Mojo::IOLoop->next_tick(sub { $self->$cb($!, []) });
    return $self;
  }

  while (my $id = readdir $CONNECTIONS) {
    next unless $id =~ /^\w+/;
    my $settings = catfile $user_dir, $id, 'connection.json';
    next unless -e $settings;
    $settings = Mojo::JSON::decode_json(Mojo::Util::slurp($settings));
    push @connections,
      Convos::Core::Connection->new({protocol => $settings->{protocol}, user => $user})->INFLATE($settings);
  }

  return \@connections unless $cb;
  return $self->tap($cb, '', \@connections);
}

=head2 delete_object

See L<Convos::Core::Backend/delete_object>.

=cut

sub delete_object {
  my ($self, $obj, $cb) = @_;
  my $method = $obj->isa('Convos::Core::User') ? '_delete_user' : '_delete_connection';

  Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      my $fc = $delay->data->{fc} = Mojo::IOLoop::ForkCall->new;
      $fc->run(sub { $self->$method($obj) }, $delay->begin);
    },
    sub {
      my ($delay, $err) = @_;
      warn "[@{[ref $obj]}] Delete object: @{[$err || 'Success']}\n" if DEBUG;
      $self->$cb($err || '');
    },
  );

  return $self;
}

=head2 messages

See L<Convos::Core::Backend/messages>.

=cut

sub messages {
  my ($self, $obj, $query, $cb) = @_;
  my $level = $query->{level} || 'info|warn|error';
  my $limit = $query->{limit} || 60;
  my $re    = $query->{match} || qr{.};
  my $found = 0;
  my ($after, $before);

  $after  = Time::Piece->strptime('%Y-%m-%dT%H:%M:%S', $query->{after})  if $query->{after};
  $before = Time::Piece->strptime('%Y-%m-%dT%H:%M:%S', $query->{before}) if $query->{before};
  $before = gmtime if !$before and !$after;
  $re = qr{\Q$re\E}i unless ref $re;
  $re = qr/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}) \[($level)\] (.*$re.*)$/;

  # TODO:
  # Need to implement logic for searching in multiple files since the _log()
  # method "rotate" files every month.
  # The search should probably be done in a fork, using Mojo::IOLoop::ForkCall.
  # We might want to add a requirement for both "before" and "after" to be set,
  # so this method doesn't run forever.
  $self->$cb('', []);    # TODO
  return $self;

  local $! = 0;
  open my $FH, '/some/log/file' or return $self->$cb($!, undef);

  while (<$FH>) {
    next unless /$re/;
    my $message = {timestamp => $1, level => $2, message => $3};
    if ($message->{message} =~ s/^<([^\s\>]+)>\s//) {
      @$message{qw( type sender )} = (privmsg => $1);
    }
    elsif ($message->{message} =~ s/^-([^\s\>]+)-\s//) {
      @$message{qw( type sender )} = (notice => $1);
    }
    elsif ($message->{message} =~ s/^\* (\S+)\s//) {
      @$message{qw( type sender )} = (action => $1);
    }
    elsif ($message->{message} =~ s/^(?:-!-\s)?//) {
      @$message{qw( type sender )} = (server => 'server');
    }

    last if ++$found == $limit;
  }

  $self->$cb($!, []);
  $self;
}

=head2 save_object

See L<Convos::Core::Backend/save_object>.

=cut

sub save_object {
  my ($self, $obj, $cb) = @_;
  my $storage_file = $self->_settings_file($obj);

  $cb ||= sub { die $_[1] if $_[1] };

  eval {
    my $dir = File::Basename::dirname($storage_file);
    File::Path::make_path($dir) unless -d $dir;
    Mojo::Util::spurt(Mojo::JSON::encode_json($obj->TO_JSON('private')), $storage_file);
    warn "[@{[ref $obj]}] Save success. ($storage_file)\n" if DEBUG;
    Mojo::IOLoop->next_tick(sub { $obj->$cb('') });
    1;
  } or do {
    my $err = $@;
    warn "[@{[ref $obj]}] Save $err ($storage_file)\n" if DEBUG;
    Mojo::IOLoop->next_tick(sub { $obj->$cb($err) });
  };

  return $self;
}

=head2 users

See L<Convos::Core::Backend/users>.

=cut

sub users {
  my ($self, $cb) = @_;
  my $home = $self->home;
  my @users;

  if (opendir(my $USERS, $home)) {
    while (my $email = readdir $USERS) {
      my $settings = $home->rel_file("$email/user.json");
      next unless $email =~ /.\@./ and -e $settings;    # poor mans regex
      push @users, Convos::Core::User->new->INFLATE(Mojo::JSON::decode_json(Mojo::Util::slurp($settings)));
    }
  }

  return \@users unless $cb;
  return $self->tap($cb, '', \@users);
}

sub _build_home {
  my $self = shift;
  my $home = shift || $ENV{CONVOS_HOME};

  if (!$home) {
    $home = File::HomeDir->my_home;
    $home = catdir($home, qw( .local share convos )) if $home;
  }
  if ($home) {
    $home = Cwd::abs_path($home) || $home;
  }

  die 'Could not figure out CONVOS_HOME. $HOME directory could not be found.' unless $home;
  warn "[Convos] Home is $home\n" if DEBUG;
  Mojo::Home->new($home);
}

sub _delete_connection {
  my ($self, $connection) = @_;
  my $path = $self->home->rel_dir(join('/', $connection->user->email, $connection->id));
  $connection->unsubscribe($_) for qw( message state users );
  File::Path::remove_tree($path, {verbose => DEBUG}) if -d $path;
}

sub _delete_user {
  my ($self, $user) = @_;
  my $path = $self->home->rel_dir($user->user->email);
  File::Path::remove_tree($path, {verbose => DEBUG}) if -d $path;
}

sub _log {
  my ($self, $obj, $ts, $message) = @_;
  my $t = gmtime($ts || time);
  my $ym = sprintf '%s/%02s', $t->year, $t->mon;
  my $FH;    # = $self->{log_fh}{$obj}{$ym};

  unless ($FH) {
    my @path = ($obj->user->email);
    push @path, $obj->id             if $obj->isa('Convos::Core::Connection');
    push @path, $obj->connection->id if $obj->isa('Convos::Core::Conversation');
    push @path, $ym;
    push @path, $obj->name           if $obj->isa('Convos::Core::Conversation');
    my $file = $self->home->rel_file(join('/', @path) . '.log');
    my $dir = File::Basename::dirname($file);
    File::Path::make_path($dir) unless -d $dir;
    delete $self->{log_fh}{$obj};    # make sure we remove old file handles
    open $FH, '>>', $file or die "Can't open log file $file: $!";
    warn "[@{[ref $obj]}] log >> $file\n" if DEBUG == 2;
  }

  flock $FH, LOCK_EX;
  print $FH $t->datetime . " $message\n";
  flock $FH, LOCK_UN;
}

sub _settings_file {
  my ($self, $obj) = @_;

  return $obj->isa('Convos::Core::Connection')
    ? $self->home->rel_file(sprintf '%s/%s/connection.json', $obj->user->email, $obj->id)
    : return $self->home->rel_file(sprintf '%s/user.json', $obj->email);
}

sub _setup {
  my $self = shift;

  Scalar::Util::weaken($self);
  $self->home($self->_build_home($self->{home})) unless ref $self->{home};
  $self->on(
    connection => sub {
      my ($self, $connection) = @_;
      Scalar::Util::weaken($self);
      $connection->on(
        message => sub {
          my ($connection, $target, $msg) = @_;
          if ($msg->{type} eq 'private') {
            $self->_log($target, $msg->{ts}, sprintf '<%s> %s', @$msg{qw( from message )});
          }
          elsif ($msg->{type} eq 'action') {
            $self->_log($target, $msg->{ts}, sprintf '* %s %s', @$msg{qw( from message )});
          }
          else {
            $self->_log($target, $msg->{ts}, sprintf '-%s- %s', @$msg{qw( from message )});
          }
        }
      );
      $connection->on(state => sub { $self->_log($_[0], undef, "-!- Change connection state to $_[1]. $_[2]") });
      $connection->on(
        users => sub {
          my ($connection, $conversation, $data) = @_;
          $self->_log($conversation, $data->{ts}, "--- x");
        }
      );
    }
  );
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
