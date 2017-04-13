package Convos::Plugin::Paste::File;
use Mojo::Base -base;

use Mojo::Path;
use Time::HiRes 'time';

has content => '';
has created_at => sub {time};

has id => sub {
  my $id = shift->created_at;
  $id =~ s!\.(\d+)!{$1 . ('0' x (5 - length $1))}!ge;    # 1492076402.3066 => 149207640230660
  $id;
};

has user => undef;

sub public_uri { Mojo::Path->new(join '/', 'paste', $_[0]->user->public_id, $_[0]->id); }
sub uri { Mojo::Path->new(join '/', $_[0]->user->email, 'paste', $_[0]->id); }

sub TO_JSON {
  my ($self, $private) = @_;
  my $json = {content => $self->content, created_at => $self->created_at};

  $json->{author} = $self->user->email if $private;

  return $json;
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Paste::File - Represents a paste

=head1 DESCRIPTION

L<Convos::Plugin::Paste::File> is a class used by the EXPERIMENTAL Convos
plugin L<Convos::Plugin::Paste>.

=head1 ATTRIBUTES

=head2 content

  $str = $self->content;

Holds the paste.

=head2 created_at

  $epoch = $self->created_at;

Defaults to L<Time::HiRes/time>.

=head2 user

  $user = $self->user;

A L<Convos::Core::User> object.

=head1 METHODS

=head2 public_uri

  $path = $self->uri;

Returns a L<Mojo::Path> object useful for making a public URL.

=head2 uri

  $path = $self->uri;

Returns a L<Mojo::Path> object representing the file on disk.

=head1 SEE ALSO

L<Convos>.

=cut
