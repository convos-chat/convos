package Convos::Plugin::Bot::Action::Facts;
use Mojo::Base 'Convos::Plugin::Bot::Action';

use Mojo::Util qw(trim);

has description => 'Add facts that you can ask for later';
has usage       => 'Use "foo is ..." to teach and "what is foo?" or "foo?" to retrieve.';

sub register {
  my ($self, $bot, $config) = @_;

  $self->_create_table;
  $self->on(message => sub { shift->_learn(@_) });

  # TODO: Use config instead?
  $self->{copula_re} = qr{(aren't|isn't|are|is|says)};
}

sub reply {
  my ($self, $event) = @_;
  return delete $self->{reply} if $self->{reply};    # reply after learning
  return undef unless my @parts = split $self->{copula_re}, $event->{message}, 3;

  my $topic  = trim $parts[-1];
  my $direct = $topic =~ s!^\W*$event->{my_nick}\W*!!;
  $topic =~ s!\?\W*$!!;

  return undef unless $topic =~ m!\w!;

  my $fact = $self->query_db(
    'select topic, copula, explanation from facts where topic = ? collate nocase
      order by case copula when ? then 0 else 1 end', $topic, $parts[1] || 'is',
  )->fetchrow_arrayref;

  # Reply with fact
  return sprintf "%s %s %s", @$fact if $fact;

  # Check if we should reply at all
  return undef if $self->event_config($event, 'suppress_do_not_know_reply');
  return undef unless $direct ||= $event->{is_private};

  my $answers = $self->event_config($event, 'answers_do_not_know')
    || [q(Sorry, I don't know anything about "%s".)];
  return @$answers ? sprintf $answers->[rand @$answers], $topic : undef;
}

sub _create_table {
  my $self = shift;

  $self->query_db(<<'HERE');
create table if not exists facts (
  topic       varchar  not null,
  copula      varchar  not null default 'is',
  explanation text  not null default 'is',
  inserted    datetime not null default current_timestamp
)
HERE

  $self->query_db('create unique index if not exists facts__topic_copula on facts (topic, copula)');
}

sub _learn {
  my ($self, $event) = @_;
  return if $event->{message} =~ m!\?\W*$!;
  return unless my @parts = split $self->{copula_re}, $event->{message}, 3;

  my $direct = $parts[0] =~ s!^\W*$event->{my_nick}\W*!!;
  @parts = map { trim $_ } grep { $_ =~ m!\w! } @parts;
  return unless @parts == 3;
  return unless 30 >= length $parts[0];

  my $replaced
    = ($direct ||= $event->{is_private})
    && $self->query_db('delete from facts where topic = ? collate nocase and copula = ?',
    @parts[0, 1])->rows;
  $self->query_db('insert or ignore into facts (topic, copula, explanation) values (?, ?, ?)',
    @parts);

  return unless $direct;
  my $answers
    = $replaced
    ? $self->event_config($event, 'answers_relearned') || ['I learned something new about %s.']
    : $self->event_config($event, 'answers_learned')   || ['I learned about %s.'];
  $self->{reply} = sprintf $answers->[rand @$answers], $parts[0] if @$answers;
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Bot::Action::Facts - Track facts of a topic

=head1 SYNOPSIS

=head2 Prerequisites

You need to install L<DBD::SQLite> to use this action:

  ./script/convos cpanm -n DBD::SQLite

=head2 Commands

=over 2

=item * foo are something

=item * foo aren't something

=item * foo is something

=item * foo isn't something

=item * foo says something

=item * foo?

=item * what are foo?

=item * what aren't foo?

=item * what is foo?

=item * what isn't foo?

=item * what says foo?

=back

=head2 Config file

  ---
  actions:
  - class: Convos::Plugin::Bot::Action::Facts
    suppress_do_not_know_reply: 0

=head1 DESCRIPTION

L<Convos::Plugin::Bot::Action::Facts> allows L<Convos::Plugin::Bot> to track
facts.

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
