package WebIrc::Plugin::Helpers;

=head1 NAME

WebIrc::Plugin::Helpers - Mojo's little helpers

=cut

use Mojo::Base 'Mojolicious::Plugin';
use WebIrc::Core::Util ();
use Mojo::JSON;

my $JSON = Mojo::JSON->new;

=head1 HELPERS

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
  my $nick     = $c->stash('nick');
  my $messages = [];

  for (my $i = 0; $i < @$conversation; $i = $i + 2) {
    my $message = $JSON->decode($conversation->[$i]);
    unless (ref $message) {
      $c->logf(debug =>'Unable to parse raw message: ' . $conversation->[$i]);
      next;
    }
    $nick //= '[server]';
    $c->stash(embed => undef);
    $message->{message} =~ s!\b(\w{2,5}://\S+)!__handle_link($c, $message,$1)!e if $message->{message};

    unshift @$messages, $message;
  }

  return $messages;
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

=head3 as_id

strip non-word characters from input.

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
  $app->helper(redis => sub { shift->app->redis(@_) });
  $app->helper(as_id => sub { my ($self, $val) = @_; $val =~ s/\W+//g; $val });
  $app->helper(send_partial => sub { $self = shift; $self->send( $self->render_partial(@_).'' ); });
  $app->helper(
    is_active => sub {
      my ($self, $c, $target) = @_;
      if ($c->{id} == $self->param('cid')) {
        return 1 if !defined $target && !defined $self->param('target');
        return 1 if defined $target && defined $self->param('target') && $target eq $self->param('target');
      }
      return 0;
    }
  );
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
