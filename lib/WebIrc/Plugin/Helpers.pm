package WebIrc::Plugin::Helpers;

=head1 NAME

WebIrc::Plugin::Helpers - Mojo's little helpers

=cut

use Mojo::Base 'Mojolicious::Plugin';
use WebIrc::Core::Util ();
use Mojo::JSON;

my $JSON = Mojo::JSON->new;

=head1 HELPERS

=head2 as_id

    $id = as_id @str;

This method will convert the input to a string which can be used as id
attribute in your HTML doc.

It will convert non-word characters to ":hex" and join C<@str> with ":00".

=cut

sub as_id {
  my $c = shift;

  join ':00', map {
    local $_ = $_; # local $_ is for changing constants and not changing input
    s/:/:3a/g;
    s/([^\w:])/{ sprintf ':%02x', ord $1 }/ge;
    $_;
  } grep {
    length $_;
  } @_;
}

=head2 id_as

    @str = id_as $id;

Reverse of L</as_id>.

=cut

sub id_as {
  map {
    s/:(\w\w)/{ chr hex $1 }/ge;
    $_;
  } split /:00/, $_[1];
}

=head2 form_block

  %= form_block $name, class => [$str, ...] begin
  ...
  % end

The code above will create this markup:

  <div class="@$class" title="$error">
    ...
  </div>

In addition, <@$class> will contain "error" if C<$error> can be fetched from the
stash hash C<errors>, using C<$name> as key.

=cut

sub form_block {
  my $content = pop;
  my ($c, $field, %args) = @_;
  my $error = $c->stash('errors')->{$field} // '';
  my $classes = $args{class} ||= [];

  push @$classes, 'error' if $error;

  $c->tag(div => class => join(' ', @$classes), title => $error, $content);
}

=head2 format_conversation

  $messages = $c->format_conversation(\@conversation);

Takes a list of JSON strings and turns them into a list of hash-refs where the
"message" key contains a formatted version with HTML and such.

=cut

sub format_conversation {
  my ($c, $conversation) = @_;
  my @messages;

  for(@$conversation) {
    my $message = $JSON->decode($_);
    unless (ref $message) {
      $c->logf(debug => "Unable to parse raw message: $_");
      next;
    }
    $c->stash(embed => undef);

    if($message->{message}) {
      $message->{message} = Mojo::Util::xml_escape($message->{message});
      $message->{message} =~ s!\b(\w{2,5}://\S+)!__handle_link($c, $message,$1)!ge;
    }

    unshift @messages, $message;
  }

  return \@messages;
}

sub __handle_link {
  my($c, $message, $link)=@_;
  my $tx = $c->app->ua->head($link);

  if(!$tx->error and $tx->res->headers->content_type =~ m{^image/}) {
    $message->{embed} .= $c->image($link);
  }

  return $c->link_to($link,$link,(target=>"_blank"));
}

=head2 logf

See L<WebIrc::Core::Util/logf>.

=head2 redis

Returns a L<Mojo::Redis> object.

=cut

sub redis {
  my $self  = shift;

  $self->stash->{redis} ||= do {
    my $log = $self->app->log;
    my $redis = Mojo::Redis->new(server => $self->config->{redis}, timeout => 600);

    $redis->on(
      error => sub {
        my ($redis, $err) = @_;
        $log->error('[REDIS ERROR] ' . $err);
      }
    );

    $redis;
  };
}

=head1 METHODS

=head2 register

Will register the L</HELPERS> above.

=cut

sub register {
  my ($self, $app) = @_;

  $app->helper(form_block    => \&form_block);
  $app->helper(format_conversation => \&format_conversation);
  $app->helper(logf          => \&WebIrc::Core::Util::logf);
  $app->helper(format_time => sub { my $self = shift; WebIrc::Core::Util::format_time(@_); });
  $app->helper(redis => \&redis);
  $app->helper(as_id => \&as_id);
  $app->helper(id_as => \&id_as);
  $app->helper(send_partial => sub { $self = shift; $self->send( $self->render_partial(@_).'' ); });
  $app->helper(
    is_active => sub {
      my ($c, $id, $target) = @_;
      if ($id eq $c->stash('cid')) {
        return 'active' if !length $target and !length $c->stash('target');
        return 'active' if length $target and length $c->stash('target') and $target eq $c->stash('target');
      }
      return '';
    }
  );
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
