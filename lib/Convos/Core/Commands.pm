package Convos::Core::Commands;

=head1 NAME

Convos::Core::Commands - Translate to IRC commands

=cut

use strict;
use warnings;
use Convos::Core::Util 'as_id';

=head1 METHODS

=head2 close

=cut

sub close {
  my ($self, $target, $dom) = @_;
  my $login = $self->session('login');
  my $id;

  $target ||= $dom->{target};

  if ($target =~ /^[#&]/) {
    return "PART $target";
  }
  else {
    $id = as_id $dom->{network}, $target;
    $self->redis->zrem(
      "user:$login:conversations",
      $id,
      sub {
        $self->send_partial('event/remove_conversation', %$dom, target => $target);
      }
    );
    return;
  }
}

=head2 help

=cut

sub help {
  my ($self) = @_;
  $self->send_partial('event/help');
  return;
}

=head2 j

=head2 join

=head2 list

=head2 me

=head2 mode

=head2 msg

=head2 names

=head2 nick

=head2 oper

=head2 part

=head2 query

=cut

sub query {
  my ($self, $target, $dom) = @_;
  my $login = $self->session('login');
  my $id = as_id $dom->{network}, $target;

  if ($target =~ /^[#&]?[\w_-]+$/) {
    $self->redis->zadd(
      "user:$login:conversations",
      time, $id,
      sub {
        $self->send_partial('event/add_conversation', %$dom, target => $target);
      }
    );
  }
  else {
    $target ||= 'Missing';
    $self->send_partial(
      'event/server_message', %$dom,
      status    => 400,
      message   => "Invalid target: $target",
      timestamp => time
    );
  }

  return;
}

=head2 reconnect

=cut

sub reconnect {
  my ($self, $arg, $dom) = @_;
  $self->app->core->control(restart => $self->session('login'), $dom->{network}, sub { });
  return;
}

=head2 say

=head2 t

=head2 topic

=head2 w

=head2 whois

=cut

sub join  {"JOIN $_[1]"}
sub list  {"LIST"}
sub me    {"PRIVMSG $_[2]->{target} :\x{1}ACTION $_[1]\x{1}"}
sub mode  {"MODE $_[1]"}
sub msg   { $_[1] =~ s!^(\w+)\s*!!; "PRIVMSG $1 :$_[1]" }
sub names { "NAMES " . ($_[1] || $_[2]->{target}) }
sub nick  {"NICK $_[1]"}
sub oper  {"OPER $_[1]"}
sub part  { "PART " . ($_[1] || $_[2]->{target}) }
sub say   {"PRIVMSG $_[2]->{target} :$_[1]"}
sub topic { "TOPIC $_[2]->{target}" . ($_[1] ? " :$_[1]" : "") }
sub whois {"WHOIS $_[1]"}

{
  no warnings 'once';
  *j = \&join;
  *t = \&topic;
  *w = \&whois;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
