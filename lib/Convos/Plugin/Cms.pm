package Convos::Plugin::Cms;
use Mojo::Base 'Convos::Plugin';

use Convos::Util 'tp';
use Mojo::ByteStream;
use Mojo::Cache;
use Mojo::Collection;
use Mojo::DOM;
use Mojo::URL;
use Mojo::Util qw(decode trim);
use Pod::Simple::Search;
use Pod::Simple::XHTML;
use Scalar::Util 'blessed';
use Text::MultiMarkdown;

has _cache => sub { Mojo::Cache->new(max_keys => 20) };
has _tmm   => sub { Text::MultiMarkdown->new };

sub register {
  my ($self, $app, $config) = @_;

  $app->defaults('cms.blogs' => Mojo::Collection->new);
  $app->config('cms.paths' => [$app->core->home->child('content'), $app->asset->assets_dir]);
  unshift @{$app->static->paths},   $app->core->home->child(qw(content public))->to_string;
  unshift @{$app->renderer->paths}, $app->core->home->child(qw(content templates))->to_string;

  $app->helper('cms.blogs_p'          => sub { $self->_blogs_p(@_) });
  $app->helper('cms.document_p'       => sub { $self->_document_p(@_) });
  $app->helper('cms.pod_to_html'      => sub { my $c = shift; _rewrite_pod($c, _pod_to_html(@_)) });
  $app->helper('cms.scan_for_blogs_p' => sub { $self->_scan_for_blogs_p(shift->app) });
}

sub _blogs_p {
  my ($self, $c, $params) = @_;
  my $blogs = $c->stash('cms.blogs');
  return @$blogs ? Mojo::Promise->resolve($blogs) : $self->_scan_for_blogs_p($c->app);
}

sub _document_p {
  my ($self, $c, $path) = @_;

  # Normalize input
  $path->[-1] =~ s!\.html$!!;
  $path->[-1] .= '.md';

  my $file;
  for my $dir (@{$c->app->config('cms.paths')}) {
    $file = $dir->child(@$path);
    last if -r $file;
  }

  my $p = Mojo::Promise->new;
  eval {
    my $md = -r $file ? $self->_parse_markdown_document($file, {}) : {};
    $self->_rewrite_href($c, $md);
    $p->resolve($md);
  } or do {
    $p->reject($@);
  };

  return $p;
}

sub _indentation {
  (sort map {/^(\s+)/} @{shift()})[0];
}

sub _parse_markdown_document {
  my ($self, $file, $params) = @_;
  my $mtime = $file->stat->mtime;
  my $doc   = $ENV{CONVOS_CMS_NO_CACHE} ? undef : $self->_cache->get("$file");
  return $doc if $doc and $doc->{mtime} == $mtime;

  $doc = {
    after_content  => '',
    before_content => '',
    custom_css     => '',
    excerpt        => '',
    meta           => {},
    mtime          => $mtime
  };

  my ($body, $FH) = ('', $file->open);
  while (readline $FH) {
    $body .= $_ and last if $. == 1 and !/^---/;    # meta header has to start with "---"
    last if $. > 1 and /^---/;                      # meta header stops with "----"
    $doc->{meta}{$1} = $2 if /^\s*(\w+)\s*:\s*(.+)/;
  }

  $body .= $_ while readline $FH;
  $body = Mojo::DOM->new($self->_tmm->markdown($body));
  $body->find('p:empty')->each('remove');

  unless ($params->{scan}) {
    $body->find('pre')->each(sub {
      my $tag      = shift;
      my $pre_text = $tag->all_text;
      $pre_text =~ s![\r\n]+$!!s;
      $tag->content($pre_text);
    });

    $body->find('style:not(.inline)')->each(sub {
      my $tag = shift;
      $doc->{custom_css} .= $tag->all_text . "\n";
      $tag->remove;
    });

    $body->find('.is-after-content')->each(sub {
      my $tag = shift;
      $doc->{after_content} .= "$tag";
      $tag->remove;
    });

    $body->find('.is-before-content')->each(sub {
      my $tag = shift;
      $doc->{before_content} .= "$tag";
      $tag->remove;
    });

    $doc->{custom_css} =~ s!</?\w+>!!g;    # Remove <p> tags inside <style>
    $doc->{body}          = $body;
    $doc->{after_content} = $doc->{after_content} ? Mojo::DOM->new($doc->{after_content}) : undef;
    $doc->{before_content}
      = $doc->{before_content} ? Mojo::DOM->new($doc->{before_content}) : undef;
  }

  if (my $h1 = $body->at('h1:is(:root)')) {
    $doc->{meta}{heading} = trim $h1->all_text;
    $doc->{meta}{title} ||= trim $h1->all_text;
    $h1->remove;
  }

  if (my $p = $body->at('p:is(:root)')) {
    $doc->{excerpt} = $p->all_text;
  }

  my $tp
    = $file->basename =~ m!(\d{4}-\d{2}-\d{2})! ? tp "${1}T00:00:00" : Time::Piece->new($mtime);
  $doc->{ts} = $tp->epoch;
  $doc->{meta}{name} = $file->basename;
  $doc->{meta}{name} =~ s!^\d{4}-\d{2}-\d{2}-!!;
  $doc->{meta}{name} =~ s!\.md$!!;
  $doc->{meta}{$_} ||= $tp->$_ for qw(mday mon year);
  $doc->{meta}{date}  ||= sprintf '%s. %s, %s', $tp->mday, $tp->month, $tp->year;
  $doc->{meta}{title} ||= $file->basename;
  $doc->{path} = "$file";
  $self->_cache->set("$file" => $doc);

  return $doc;
}

# Heavily inspired by Mojolicious::Plugin::MojoDocs
sub _pod_to_html {
  return '' unless defined(my $pod = ref $_[0] eq 'CODE' ? shift->() : shift);

  my $parser = Pod::Simple::XHTML->new;
  $parser->perldoc_url_prefix('https://metacpan.org/pod/');
  $parser->$_('') for qw(html_header html_footer);
  $parser->anchor_items(1);
  $parser->strip_verbatim_indent(\&_indentation);
  $parser->output_string(\(my $output));
  return $@ unless eval { $parser->parse_string_document("$pod"); 1 };
  return $output;
}

sub _rewrite_href {
  my ($self, $c, $md) = @_;

  for my $section (grep { $md->{$_} } qw(after_content before_content body)) {
    $md->{$section}->find('a[href^="/"]')->each(sub { $_[0]->{href} = $c->url_for($_[0]->{href}) });
    $md->{$section}->find('img[src^="/"]')->each(sub { $_[0]->{src} = $c->url_for($_[0]->{src}) });
  }
}

# Heavily inspired by Mojolicious::Plugin::MojoDocs
sub _rewrite_pod {
  my ($c, $html) = @_;

  my $dom      = Mojo::DOM->new($html);
  my $base_url = $c->url_for('/doc/');
  $_->{href} =~ s!^https://metacpan\.org/pod/!$base_url! and $_->{href} =~ s!::!/!gi
    for $dom->find('a[href]')->map('attr')->each;

  for my $e ($dom->find('pre > code')->each) {
    next if (my $str = $e->content) =~ /^\s*(?:\$|Usage:)\s+/m;
    next unless $str =~ /[\$\@\%]\w|-&gt;\w|^use\s+\w/m;
    my $attrs = $e->attr;
    my $class = $attrs->{class};
  }

  return Mojo::ByteStream->new("$dom");
}

sub _scan_for_blogs_p {
  my ($self, $app) = @_;

  return Mojo::IOLoop->subprocess->run_p(sub {
    my @blogs;
    for my $year ($app->core->home->child(qw(content blog))->list({dir => 1})->each) {
      return unless $year->basename =~ m!^(\d{4})$!;
      push @blogs,
        $year->list->map(sub { $self->_parse_markdown_document(shift, {scan => 1}) })->each;
    }

    return [sort { $b->{ts} <=> $a->{ts} } @blogs];
  })->then(sub {
    my $blogs = Mojo::Collection->new(@{$_[0]});
    $app->defaults('cms.blogs' => $blogs);
    return $blogs;
  });
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Cms - Plugin for rendering custom content

=head1 DESCRIPTION

L<Convos::Plugin::Cms> is a L<Convos::Plugin> for rendering custom content.

=head1 METHODS

=head2 register

  $cms->register($app, \%config);

Used to register this plugin i L<Convos>.

=head1 SEE ALSO

L<Convos>.

=cut
