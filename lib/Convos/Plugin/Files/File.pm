package Convos::Plugin::Files::File;
use Mojo::Base -base;

use Carp 'confess';
use Convos::Util qw(DEBUG short_checksum);
use Digest::MD5 ();
use Mojo::Asset::File;
use Mojo::File;
use Mojo::JSON qw(false true);
use Mojo::Path;
use Mojo::Util 'encode';
use Time::HiRes 'time';

has asset    => sub { Mojo::Asset::File->new };
has filename => sub { die 'filename() cannot be built' };

has id => sub {
  my $self  = shift;
  my $asset = $self->asset;
  confess "Cannot create id() from empty file" unless $asset->path and -s $asset->path;
  return short_checksum(Digest::MD5->new->add($asset->slurp)->hexdigest);
};

has path => sub {
  my $self = shift;
  my @uri  = split '/', $self->uri;
  $uri[-1] =~ s!\.json$!.data!;
  return $self->user->core->home->child(@uri);
};

has saved      => sub { Mojo::Date->new->to_datetime };
has types      => sub { Mojolicious::Types->new };
has user       => undef;
has write_only => sub {false};

sub handle_message_to_paste_p {
  my ($class, $backend, $connection, $message) = @_;
  my $self = $class->new(user => $connection->user);

  my $filename = $message =~ m!(\w.{4,})!m ? lc substr $1, 0, 28 : 'paste';
  $filename =~ s![^A-Za-z-]+!_!g;
  $filename = 'paste' if 5 > length $filename;
  $self->filename("$filename.txt");
  $self->asset->add_chunk(encode 'UTF-8', $message);

  return $self->save_p;
}

sub load_p {
  my $self = shift;

  return $self->user->core->backend->load_object_p($self)->then(sub {
    my $attrs = shift;
    return $self->_parse_attrs($attrs) if $attrs->{id};

    # back compat
    $self->{uri} = Mojo::Path->new(join '/', $self->user->email, 'upload', $self->id);
    return $self->user->core->backend->load_object_p($self)
      ->then(sub { $self->_move_legacy_p(shift) });
  });
}

sub mime_type {
  my $self = shift;
  my $type = $self->types->type($self->_ext) || 'application/octet-stream';
  return $type eq 'application/octet-stream' && -T $self->path ? 'text/plain' : $type;
}

sub public_url {
  my $self = shift;
  my $id   = $self->id;
  $id .= '.' . $self->_ext if shift;
  return $self->user->core->web_url(join '/', 'file', $self->user->uid, $id)->to_abs;
}

sub save_p {
  my $self  = shift;
  my $asset = $self->asset;
  my $core  = $self->user->core;

  if ($asset->cleanup) {
    my $dir = $self->path->dirname;
    $dir->make_path unless -d $dir;
    $asset->move_to($self->path);
    warn "[@{[$self->id]}] Moved asset to @{[$self->path]}\n" if DEBUG;
  }

  return $core->backend->save_object_p($self);
}

sub to_message {
  shift->public_url->to_string;
}

sub uri {
  my $self = shift;
  return delete $self->{uri} if $self->{uri};    # back compat
  return Mojo::Path->new(join '/', $self->user->email, 'upload', $self->id . '.json');
}

sub _ext { shift->filename =~ m!\.(\w+)$! ? $1 : 'bin' }

sub _move_legacy_p {
  my ($self, $attrs) = @_;
  return $self unless defined $attrs->{content};

  $self->asset->add_chunk($attrs->{content});
  $self->filename('paste.txt');
  $self->saved(Mojo::Date->new($attrs->{created_at})->to_datetime);

  return $self->save_p->then(sub {
    $self->{uri} = Mojo::Path->new(join '/', $self->user->email, 'upload', $self->id);
    return $self->user->core->backend->delete_object_p($self);
  });
}

sub _parse_attrs {
  my ($self, $attrs) = @_;
  $self->$_($attrs->{$_} // '') for qw(filename id saved write_only);
  $self->asset->path($self->path) if $attrs->{id};
  return $self;
}

sub TO_JSON {
  my ($self, $persist) = @_;
  my $json = {
    ext        => $self->_ext,
    id         => $self->id,
    filename   => $self->filename,
    saved      => $self->saved,
    uid        => '' . $self->user->uid,    # force to string
    write_only => $self->write_only,
  };

  $json->{url}    = $self->public_url->to_string unless $persist;
  $json->{author} = $self->user->email if $persist;

  return $json;
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Files::File - Represents a paste

=head1 DESCRIPTION

L<Convos::Plugin::Files::File> is a class used by represent an uploaded file.

=head1 ATTRIBUTES

=head2 asset

  $str = $file->asset;

Holds a L<Mojo::Asset::File> object.

=head2 filename

  $str = $file->filename;
  $file = $file->filename($str);

Holds the original filename.

=head2 id

  $str = $file->id;

Returns an ID for the file that will be used publically in the generated URL.

=head2 path

  $path = $file->path;

Returns a L<Mojo::File> object for where the asset should be on disk.

=head2 saved

  $dt = $file->saved;

Holds a date-tim string for when the file was saved.

=head2 types

  $types = $file->types;

Holds a L<Mojolicious::Types> object, used by L</mime_type>.

=head2 user

  $user = $file->user;

Holds a L<Convos::Core::User> object.

=head2 write_only

  $bool = $file->write_only;
  $file = $file->write_only(true);

Used to write files that should only be used internally by L<Convos>, instead
of read by visitors on the web.

=head1 METHODS

=head2 handle_message_to_paste_p

  $p = Convos::Plugin::Files::File
        ->handle_message_to_paste_p($backend, $connection, $message)
        ->then(sub { my $file = shift });

This method will be called when a L<Convos::Core::Connection> wants to create a
paste.

=head2 load_p

  $p = $file->load_p->then(sub { my $file = shift });

Used to load meta information from disk.

=head2 mime_type

  $str = $file->mime_type;

Used to get the mime type of this file. Defaults to "application/octet-stream".

=head2 public_url

  $path = $file->public_url;

Returns a L<Mojo::Path> object useful for making a public URL.

=head2 save_p

  $p = $file->save_p->then(sub { my $file = shift });

=head2 to_message

  $str = $file->to_message;

Converts this objcet into a message you can send to a channel or user.

=head2 uri

  $path = $file->uri;

Returns a L<Mojo::Path> object representing the file on disk.

=head1 SEE ALSO

L<Convos>.

=cut
