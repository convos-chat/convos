package Convos::Plugin::Bot::Action::Karma;
use Mojo::Base 'Convos::Plugin::Bot::Action';

has description => 'Track karma of a nick or topic.';
has usage       => 'karma <topic>, <topic>++, <topic>--.';

sub register {
  my ($self, $bot, $config) = @_;

  $self->_create_table;
  $self->on(message => sub { shift->_learn(@_) });
}

sub reply {
  my ($self, $event) = @_;
  return undef unless $event->{message} =~ m/^karma\s+(.+)/i;

  my $topic = $1;
  $topic =~ s/[?!.]$//;
  my ($positive, $negative, $reason) = (
    $self->_select('select sum(karma) from karma where topic = ? and karma > 0',      $topic),
    $self->_select('select abs(sum(karma)) from karma where topic = ? and karma < 0', $topic),
    $self->_select(
      'select reason from karma where topic = ? and length(reason) order by random()', $topic
    ),
  );

  $positive ||= 0;
  $negative ||= 0;
  return sprintf '"%s" has neither negative nor positive karma.', $topic
    unless $positive + $negative;

  return sprintf 'Karma for %s is %s (+%s/-%s) and reason "%s".', $topic, ($positive - $negative),
    $positive, $negative, $reason || 'No reason';
}

sub _create_table {
  my $self = shift;

  $self->query_db(<<'HERE');
create table if not exists karma (
  topic    varchar  not null,
  karma    int      not null,
  reason   text     not null default '',
  inserted datetime not null default current_timestamp
)
HERE

  $self->query_db('create index if not exists karma__topic on karma (topic)');
}

sub _learn {
  my ($self, $event) = @_;
  return unless $event->{message} =~ m!^\s*(\S+)\s*(\+\+|--)(.*)!;

  my ($reason, $topic) = ($3, $1);
  my $karma = $2 eq '--' ? -1 : 1;
  $reason =~ s!^[\s#]+!!;
  $reason =~ s!\s+$!!;
  $reason = '' unless $reason =~ m!\S!;

  $self->query_db('insert into karma (topic, karma, reason) values (?, ?, ?)',
    $topic, $karma, $reason);
}

sub _select { shift->query_db(@_)->fetchrow_array }

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Bot::Action::Karma - Track karma of a topic

=head1 SYNOPSIS

=head2 Prerequisites

You need to install L<DBD::SQLite> to use this action:

  ./script/convos cpanm -n DBD::SQLite

=head2 Commands

=over 2

=item * <topic>++ # reason

Will increase karma for a topic, with an optional reason:

  convos++
  convos++ some reason
  convos++ # some reason

=item * <topic>-- # reason

Will decrease karma for a topic, with an optional reason:

  superman--
  superman-- some reason
  superman-- # some reason

=item * karma <topic>

Relies with karma for a C<topic> and a random reason.

=back

=head2 Config file

  ---
  actions:
  - class: Convos::Plugin::Bot::Action::Karma

=head1 DESCRIPTION

L<Convos::Plugin::Bot::Action::Core> allows L<Convos::Plugin::Bot> to track
karma for topics.

=head1 ATTRIBUTES

=head2 description

See L<Convos::Plugin::Bot::Action/description>.

=head2 usage

See L<Convos::Plugin::Bot::Action/usage>.

=head1 METHODS

=head2 register

Loads L<DBD::SQLite> and sets up the C<karma.sqlite> database.

=head2 reply

Can reply to one of the L</Commands>.

=head1 SEE ALSO

L<Convos::Plugin::Bot>.

=cut
