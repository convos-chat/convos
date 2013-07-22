package WebIrc::Plugin::Helpers;

=head1 NAME

WebIrc::Plugin::Helpers - Mojo's little helpers

=cut

use Mojo::Base 'Mojolicious::Plugin';
use WebIrc::Core::Util ();
use constant DEBUG => $ENV{WIRC_DEBUG} ? 1 : 0;

my $YOUTUBE_INCLUDE = '<iframe width="390" height="220" src="//www.youtube-nocookie.com/embed/%s?rel=0&amp;wmode=opaque" frameborder="0" allowfullscreen></iframe>';

=head1 HELPERS

=head2 id_as

See L<WebIrc::Core::Util/id_as>.

=head2 as_id

See L<WebIrc::Core::Util/as_id>.

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
  my $error = $c->stash->{errors}{$field} // '';
  my $classes = $args{class} ||= [];

  push @$classes, 'error' if $error;

  $c->tag(div => class => join(' ', @$classes), title => $error, $content);
}

=head2 format_conversation

  $c->format_conversation(\&iterator, \&callback);

Takes a list of JSON strings and turns them into a list of hash-refs where the
"message" key contains a formatted version with HTML and such. The result will
be passed on to the C<$callback>.

=cut

sub format_conversation {
  my ($c, $conversation, $cb) = @_;
  my $ua = Mojo::UserAgent->new(request_timeout => 2, connect_timeout => 2);
  my $delay = Mojo::IOLoop->delay;
  my $current_nick = $c->stash('nick') || '';
  my @messages;

  my $url_formatter = sub {
    my($data, $url) = @_;
    my $cb = $delay->begin;

    if($url =~ m!youtube.com\/watch?.*?\bv=([^&]+)!) {
      $data->{embed} = sprintf $YOUTUBE_INCLUDE, $1;
      $cb->();
    }
    else {
      $ua->head($url => sub {
        my $ct = $_[1]->res->headers->content_type || '';
        $data->{embed} = $c->image($url, alt => 'Embedded media') if $ct =~ /^image/;
        $cb->();
      });
    }

    $c->link_to($url, $url, target => '_blank');
  };

  while(my $message = $conversation->()) {
    $message->{embed} = '';

    if($message->{message}) {
      my $lookup = $message->{host} ? join '@', @$message{qw/ user host /} : $message->{nick}; # need to check for "host" to be backward compat
      my $cb = $delay->begin;

      $lookup =~ s!^~!!;
      $c->redis->get("avatar:$lookup", sub {
        my $lookup = $_[1] || $lookup;
        my $avatar = Mojo::Util::md5_sum($lookup);
        $message->{avatar} = "https://secure.gravatar.com/avatar/$avatar?s=40&d=retro";
        $cb->();
      });

      $message->{message} = Mojo::Util::xml_escape($message->{message});
      $message->{message} =~ s!\b(\w{2,5}://\S+)!{$url_formatter->($message, $1)}!ge;
      $message->{highlight} ||= 0;
    }

    push @messages, $message;
  }

  $delay->once(finish => sub { $c->$cb(\@messages) });
  $delay->begin->(); # need to do at least one step
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

  $app->helper(form_block => \&form_block);
  $app->helper(format_conversation => \&format_conversation);
  $app->helper(logf => \&WebIrc::Core::Util::logf);
  $app->helper(format_time => sub { my $self = shift; WebIrc::Core::Util::format_time(@_); });
  $app->helper(redis => \&redis);
  $app->helper(as_id => sub { shift; WebIrc::Core::Util::as_id(@_) });
  $app->helper(id_as => sub { shift; WebIrc::Core::Util::id_as(@_) });
  $app->helper(send_partial => sub { my $c = shift; $c->send($c->render(@_, partial => 1)->to_string); });
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
