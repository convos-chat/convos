package Convos::Util;
use Mojo::Base 'Exporter';
use Mojo::Util 'monkey_patch';
use constant DEBUG => $ENV{CONVOS_DEBUG} || 0;

our @EXPORT_OK = qw(DEBUG has_many);

sub has_many {
  my $class = caller;
  my ($accessor, $related, $constructor) = @_;
  my ($setter,   $getter,  $remover)     = ($accessor);

  $setter =~ s!s$!!;
  $getter  = "get_$setter";
  $remover = "remove_$setter";

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
    my $id = lc(ref $attrs ? $attrs->{id} || $related->id($attrs) : $attrs);
    return $self->{$accessor}{$id};
  };

  $class->can($remover) or monkey_patch $class => $remover => sub {
    my ($self, $attrs) = @_;
    my $id = lc(ref $attrs ? $attrs->{id} || $related->id($attrs) : $attrs);
    return delete $self->{$accessor}{$id};
  };
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

=head1 SEE ALSO

L<Convos>.

=cut
