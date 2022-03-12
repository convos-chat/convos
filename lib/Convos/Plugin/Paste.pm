package Convos::Plugin::Paste;
use Mojo::Base 'Convos::Plugin', -async_await;

use Convos::Core::User::File;
use Mojo::Util qw(encode);

sub register {
  my ($self, $app, $config) = @_;

  # This is not really relevant for this plugin, but placing it here for now in
  # lack of a better place
  $app->helper('user.file' => sub { Convos::Core::User::File->new(log => shift->log, @_) });
  $app->core->backend->on(message_to_paste => \&_message_to_paste_p);
}

async sub _message_to_paste_p {
  my ($backend, $connection, $message) = @_;
  my $file     = Convos::Core::User::File->new(user => $connection->user);
  my $filename = $message =~ m!(\w.{4,})!m ? lc substr $1, 0, 28 : 'paste';
  $filename =~ s![^A-Za-z-]+!_!g;
  $filename = 'paste' if 5 > length $filename;
  $file->filename("$filename.txt");
  $file->asset->add_chunk(encode 'UTF-8', $message);
  await $file->save_p;
  return $file->public_url->to_string;
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Paste - A plugin for creating a pastebin instead of flooding IRC

=head1 DESCRIPTION

L<Convos::Plugin::Paste> is a plugin for creating an internal paste, private to
your convos instance, instead of flooding ex. an IRC channel.

The functionality of this plugin could be replaced with something like this:

  package Convos::Plugin::Ix;
  use Mojo::Base 'Convos::Plugin';

  sub register {
    my ($self, $app, $config) = @_;
    my $ua = $app->ua;

    $app->core->backend->on(message_to_paste => sub {
      my ($backend, $connection, $message) = @_;

      return $ua->post_p('http://ix.io', form => {'f:1' => $message})->then(sub {
        my $tx = shift;
        my $err = $tx->error && $tx->error->{message};
        return Mojo::Promise->reject($err) if $err;

        # The body contains the URL to the paste and instead of just returning the
        # URL, the message can be customized further:
        return sprintf 'My message is long, so I made a paste: %s', $tx->res->body;
      });
    });
  }

  1;

=head1 METHODS

=head2 register

  $self->register($app, \%config)

=head1 SEE ALSO

L<Convos::Core::User::File> and L<Convos>.

=cut
