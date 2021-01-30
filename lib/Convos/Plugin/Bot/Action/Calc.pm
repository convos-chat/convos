package Convos::Plugin::Bot::Action::Calc;
use Mojo::Base 'Convos::Plugin::Bot::Action';

use Convos::Util 'require_module';

has description => 'Calculate a mathematical expression.';
has usage       => 'calc 1 + 2';

sub register {
  my ($self, $bot, $config) = @_;
  require_module 'Math::Calc::Parser';
}

sub reply {
  my ($self, $event) = @_;
  return undef unless $event->{message} =~ m/^calc\S*\s+(.+)/;

  my $expr = $1;
  return eval { sprintf '%s = %s', $expr, Math::Calc::Parser->evaluate($expr) } || do {
    $@ =~ s!\sat\s\S+.*!!s;
    chomp $@;
    $@;
  };
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Bot::Action::Calc - Compute mathematical expressions

=head1 SYNOPSIS

=head2 Prerequisites

You need to install L<Math::Calc::Parser> to use this action:

  ./script/convos cpanm -n Math::Calc::Parser

=head2 Commands

=over 2

=item * calc <expression>

Will pass "expression> to L<Math::Calc::Parser> which will try to generate a response.

=back

=head2 Config file

  ---
  actions:
  - class: Convos::Plugin::Bot::Action::Calc

=head1 DESCRIPTION

L<Convos::Plugin::Bot::Action::Core> allows L<Convos::Plugin::Bot> to compute
math expressions.

=head1 ATTRIBUTES

=head2 description

See L<Convos::Plugin::Bot::Action/description>.

=head2 usage

See L<Convos::Plugin::Bot::Action/usage>.

=head1 METHODS

=head2 register

Loads L<Math::Calc::Parser>.

=head2 reply

Can reply to one of the L</Commands>.

=head1 SEE ALSO

L<Convos::Plugin::Bot>.

=cut
