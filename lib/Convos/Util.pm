package Convos::Util;
use Mojo::Base 'Exporter';

use JSON::Validator::Error;
use Mojo::Util 'monkey_patch';
use constant DEBUG => $ENV{CONVOS_DEBUG} || 0;

our @EXPORT_OK = qw(DEBUG E has_many next_tick spurt);

sub E {
  my ($msg, $path) = @_;
  $msg =~ s! at \S+.*!!s;
  $msg =~ s!:.*!.!s;
  return {errors => [JSON::Validator::Error->new($path, $msg)]};
}

sub has_many {
  my $class = caller;
  my ($accessor, $related, $constructor) = @_;
  my ($setter,   $getter,  $remover)     = ($accessor);

  $setter =~ s!s$!!;
  $getter  = "get_$setter";
  $remover = "remove_$setter";

  warn "[Convos::Util] Adding $accessor(), $setter() and $getter() to $class\n" if DEBUG >= 2;

  monkey_patch $class => $accessor => sub {
    return [values %{$_[0]->{$accessor} || {}}];
  };

  monkey_patch $class => $setter => sub {
    my ($self, $attrs) = @_;
    my $id = $related->id($attrs);
    my $obj = $self->{$accessor}{$id} || $self->$constructor($attrs);
    map { $obj->{$_} = $attrs->{$_} } keys %$attrs if $self->{$accessor}{$id};
    $self->{$accessor}{$id} = $obj;
  };

  monkey_patch $class => $getter => sub {
    my ($self, $attrs) = @_;
    my $id = ref $attrs ? $attrs->{id} || $related->id($attrs) : $attrs;
    die "Could not build 'id' for $class" unless defined $id;
    return $self->{$accessor}{lc($id)};
  };

  $class->can($remover) or monkey_patch $class => $remover => sub {
    my ($self, $attrs) = @_;
    my $id = lc(ref $attrs ? $attrs->{id} || $related->id($attrs) : $attrs);
    return delete $self->{$accessor}{$id};
  };
}

sub next_tick {
  my ($obj, $cb, @args) = @_;
  Mojo::IOLoop->next_tick(sub { $obj->$cb(@args) });
  return $obj;
}

sub spurt {
  my ($content, $path) = @_;
  Mojo::Util::spurt($content => "$path.tmp");
  unlink $path or die "Can't delete old file: $path" if -e $path;
  rename "$path.tmp" => $path;
  return $content;
}

# See also Mojo::Util::_stash()
sub _stash {
  my ($name, $object) = (shift, shift);
  return $object->{$name} ||= {} unless @_;
  return $object->{$name}{$_[0]} unless @_ > 1 || ref $_[0];

  my $values = ref $_[0] ? $_[0] : {@_};
  @{$object->{$name}}{keys %$values} = values %$values;
  return $object;
}

1;

=encoding utf8

=head1 NAME

Convos::Util - Utility functions

=head1 SYNOPSIS

  package Convos::Core::Core;
  use Convos::Util qw(DEBUG has_many);

=head1 DESCRIPTION

L<Convos::Util> is a utily module for L<Convos>.

=head1 FUNCTIONS

=head2 has_many

  has_many $attribute => $related_class => sub {
    my ($self, $attrs) = @_;
    return $related_class->new($attrs);
  };

Used to automatically define a create/update, get and list method to the
caller class. Example:

  has_many users => "Convos::Core::User" => sub {
    my ($self, $attrs) = @_;
    return Convos::Core::User->new($attrs);
  };

The definition above results in the following methods:

  # Create or update and existing Convos::Core::User object
  $user = $class->user(\%attrs);

  # Retrieve a Convos::Core::User object or undef()
  $user = $class->get_user($id);
  $user = $class->get_user(\%attrs);

  # Retrieve an array-ref of Convos::Core::User objects
  $users = $class->users;

  # Remove a user
  $user = $class->remove_user($id);
  $user = $class->remove_user(\%attrs);

=head2 next_tick

  $obj = next_tick $obj, sub { my ($obj, @args) = @_ }, @args;

Wrapper around L<Mojo::IOLoop/next_tick>.

=head2 spurt

  $bytes = spurt $bytes => $path;

Write all C<$bytes> at to a temp file, and then replace C<$path> with the temp
file. This is almost the same as L<Mojo::Util/spurt>, but will not truncate
existing files, if the disk is full.

=head1 SEE ALSO

L<Convos>.

=cut
