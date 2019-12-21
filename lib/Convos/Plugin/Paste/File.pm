package Convos::Plugin::Paste::File;
use Mojo::Base -base;

use Mojo::Path;
use Time::HiRes 'time';

has content    => '';
has created_at => sub {time};

has id => sub {
  my $id = shift->created_at;
  $id =~ s!\.(\d+)!{$1 . ('0' x (5 - length $1))}!ge;    # 1492076402.3066 => 149207640230660
  $id;
};

has user => undef;
has url  => undef;

sub handle_event_p {
  my ($class, $backend, $connection, $message_ref) = @_;
  my $self = $class->new(content => $$message_ref, user => $connection->user);

  return $backend->save_object_p($self)->then(sub {
    $self->url($self->user->core->web_url($self->public_uri)->to_abs);
    return $self;
  });
}

sub public_uri { Mojo::Path->new(join '/', 'paste',            $_[0]->user->public_id, $_[0]->id); }
sub to_message { shift->url->to_string }
sub uri        { Mojo::Path->new(join '/', $_[0]->user->email, 'upload',               $_[0]->id); }

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

=head2 handle_event_p

  $self->handle_event_p($backend, $connection, $message_ref);

This method will be called when a C<$connection> wants to create a paste.

=head2 public_uri

  $path = $self->public_uri;

Returns a L<Mojo::Path> object useful for making a public URL.

=head2 to_message

  $str = $self->to_message;

Converts this objcet into a message you can send to a channel or user.

=head2 uri

  $path = $self->uri;

Returns a L<Mojo::Path> object representing the file on disk.

=head1 SEE ALSO

L<Convos>.

=cut
