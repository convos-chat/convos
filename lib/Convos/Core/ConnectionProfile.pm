package Convos::Core::ConnectionProfile;
use Mojo::Base -base;

use List::Util qw(first);
use Mojo::JSON qw(false true);
use Mojo::Util qw(trim);

has core                  => sub { Convos::Core->new }, weak => 1;
has loaded                => sub {false};
has max_bulk_message_size => sub { $ENV{CONVOS_MAX_BULK_MESSAGE_SIZE} || 3 };
has max_message_length    => sub { $ENV{CONVOS_MAX_MESSAGE_LENGTH}    || 512 };
has service_accounts => sub { +[split /,/, $ENV{CONVOS_SERVICE_ACCOUNTS} // 'chanserv,nickserv'] };
has url              => sub { Mojo::URL->new('irc://localhost') };
has webirc_password  => sub { $ENV{sprintf 'CONVOS_WEBIRC_PASSWORD_%s', uc shift->name} // '' };

sub find_service_account {
  my $self   = shift;
  my %needle = map { (lc $_ => $_) } @_;
  my $found  = first { $needle{lc($_)} } @{$self->service_accounts};
  return $found && $needle{$found};
}

sub id { ($_[1] || $_[0])->{id} }

sub load_p {
  my $self = shift;
  return $self->core->backend->load_object_p($self, @_)
    ->then(sub { $self->_set_attributes(shift, 1)->loaded(true) });
}

sub name { +(split '-', $_[0]->id)[1] || $_[0]->url->host }

sub save_p {
  my $self = shift;
  $self->_set_attributes(shift) if ref $_[0] eq 'HASH';
  return $self->core->backend->save_object_p($self, @_);
}

sub split_message {
  my ($self, $message) = @_;
  return [split /\n\r?/, $message] if length($message) < $self->max_message_length;

  my @messages;
  while (length $message) {
    $message =~ s!^\r*\n*!!s;
    $message =~ s!^(.*)!!m;
    my $line = $1;

    # No need to check anymore, since we are going to make a paste anyways
    return \@messages if @messages >= $self->max_bulk_message_size;

    # Line is short
    if (length($line) < $self->max_message_length) {
      push @messages, $line;
      next;
    }

    # Split long lines into multiple lines
    my @chunks = split /(\s)/, $line;
    $line = '';
    while (@chunks) {
      my $chunk = shift @chunks;

      # Force break, in case it's just one long word
      if ($self->max_message_length < length $chunk) {
        unshift @chunks, substr($chunk, 0, $self->max_message_length - 1, ''), $chunk;
        next;
      }

      $line .= $chunk;
      my $next = @chunks && $chunks[0] || '';
      if ($self->max_message_length < length "$line$next") {
        push @messages, trim $line;
        $line = '';
      }
    }

    # Add remaining chunk
    push @messages, trim $line if length $line;
  }

  return \@messages;
}

sub too_long_messages {
  my ($self, $messages) = @_;
  return $self->max_bulk_message_size <= @$messages
    || $self->max_message_length < length $messages->[0];
}

sub uri { Mojo::Path->new(sprintf 'settings/connections/%s.json', $_[0]->id) }

sub _set_attributes {
  my ($self, $params) = @_;

  $self->$_($params->{$_})
    for grep { defined $params->{$_} }
    qw(max_bulk_message_size max_message_length service_accounts webirc_password);

  return $self;
}

sub TO_JSON {
  my $self = shift;

  return {
    id                    => $self->id,
    max_bulk_message_size => $self->max_bulk_message_size,
    max_message_length    => $self->max_message_length,
    service_accounts      => $self->service_accounts,
    url                   => $self->url->to_string,
    webirc_password       => $self->webirc_password,
  };
}

1;

=encoding utf8

=head1 NAME

Convos::Core::ConnectionProfile - Default settings for connections

=head1 DESCRIPTION

L<Convos::Core::ConnectionProfile> is a class that represents the default
settings for a L<Convos::Core::Connection>.

=head1 ATTRIBUTES

=head2 core

  $core = $connection_settings->core;

A L<Convos::Core> object.

=head2 id

  $str = $connection_settings->id;

A unique identifier.

=head2 max_bulk_message_size

  $int = $connection_settings->max_bulk_message_size;
  $connection_settings = $connection_settings->max_bulk_message_size(3);

Max number of lines before L</too_long_messages> will return true.

=head2 max_message_length

  $int = $connection_settings->max_message_length;
  $connection_settings = $connection_settings->max_message_length(512);

Max number of characters before L</split_message> will split a single message.
Also used by L</too_long_messages> to detect if the message is too long.

=head2 service_accounts

  $array_ref = $connection_settings->service_accounts;
  $connection_settings = $connection_settings->service_accounts([qw(chanserv nickserv)]);

List of service accounts for this connection.

=head2 url

  $url = $connection_settings->url;
  $connection_settings = $connection_settings->url(Mojo::URL->new);

The default URL for a connection.

=head2 webirc_password

  $str = $connection_settings->webirc_password;
  $connection_settings = $connection_settings->webirc_password('s3cret');

A password used when identifying with a WEBIRC ready IRC server.

=head1 METHODS

=head2 find_service_account

  $str = $connection_settings->find_service_account(@str);

Returns the first match in L</service_accounts> or C<undef>.

=head2 load_p

  $p = $connection_settings->load_p;

Load settings from L<Convos::Core::Backend>.

=head2 name

  $str = $connection_settings->name;

The name part from L</id>.

=head2 save_p

  $p = $connection_settings->save_p;

Save settings to L<Convos::Core::Backend>.

=head2 split_message

  $messages = $connection_settings->split_message($str);

Split C<$str> based on L</max_message_length>.

=head2 too_long_messages

  $bool = $connection_settings->too_long_messages(\@messages);

Returns true if C<@messages> violate either L</max_bulk_message_size> or
L</max_message_length>.

=head2 uri

  $str = $connection_settings->uri;

The URI used by L<Convos::Core::Backend> when saving this object.

=head1 SEE ALSO

L<Convos>, L<Convos::Core::Connection>.

=cut
