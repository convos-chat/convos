package Convos::Plugin::Cms;
use Mojo::Base 'Convos::Plugin';

use Convos::Date 'dt';
use Mojo::ByteStream;
use Mojo::Cache;
use Mojo::Collection;
use Mojo::DOM;
use Mojo::URL;
use Mojo::Util qw(decode slugify trim);
use Pod::Simple::Search;
use Pod::Simple::XHTML;
use Scalar::Util 'blessed';
use Text::Markdown;

$ENV{CONVOS_CMS_SCAN_INTERVAL} ||= 15;

has _cache => sub { Mojo::Cache->new(max_keys => 20) };
has _md    => sub { Text::Markdown->new(empty_element_suffix => '>', trust_list_start_value => 1) };

sub register {
  my ($self, $app, $config) = @_;

  $app->defaults('cms.blogs' => Mojo::Collection->new);
  $app->config('cms.paths' => [$app->core->home->child('content'), $app->asset->assets_dir]);
  unshift @{$app->static->paths},   $app->core->home->child(qw(content public))->to_string;
  unshift @{$app->renderer->paths}, $app->core->home->child(qw(content templates))->to_string;

  $app->helper('cms.blogs_p'          => sub { $self->_blogs_p(@_) });
  $app->helper('cms.document_p'       => sub { $self->_document_p(@_) });
  $app->helper('cms.perldoc'          => sub { $self->_perldoc(@_) });
  $app->helper('cms.scan_for_blogs_p' => sub { $self->_scan_for_blogs_p(shift->app) });

  Mojo::IOLoop->recurring($ENV{CONVOS_CMS_SCAN_INTERVAL} => sub { $app->cms->scan_for_blogs_p });
}

sub _blogs_p {
  my ($self, $c, $params) = @_;
  my $blogs = $c->stash('cms.blogs');
  return @$blogs ? Mojo::Promise->resolve($blogs) : $self->_scan_for_blogs_p($c->app);
}

sub _document_p {
  my ($self, $c, $path) = @_;

  # Normalize input
  $path = [@$path];
  my $format = $path->[-1] =~ s!\.(html|txt|yaml)$!! ? $1 : 'html';
  $path->[-1] .= '.md';

  my $file;
  for my $dir (@{$c->app->config('cms.paths')}) {
    $file = $dir->child(@$path);
    last if -r $file;
  }

  my $p = Mojo::Promise->new;
  eval {
    $p->resolve({}) unless -r $file;
    $p->resolve({body => $file->slurp, format => $format}) if $format eq 'txt';
    my $doc = $self->_get_cached_document($file) || $self->_parse_document($file, {});
    $doc->{format} = $format;
    $self->_rewrite_href($c, $doc) if $format eq 'html';
    $p->resolve($doc);
  } or do {
    $p->reject($@);
  };

  return $p;
}

sub _extract_excerpt {
  my ($self, $dom, $doc) = @_;
  my $p = $dom->at('p:is(:root)') or return;
  $doc->{excerpt} = $p->all_text;
  $doc->{meta}{description}
    ||= length($doc->{excerpt}) > 150 ? substr($doc->{excerpt}, 0, 160) . '...' : $doc->{excerpt};
  $doc->{meta}{description} =~ s!\r?\n! !g;
}

sub _extract_heading {
  my ($self, $dom, $doc) = @_;
  my $h1 = $dom->at('h1:is(:root)') or return;
  $doc->{meta}{heading} = trim $h1->all_text;
  $doc->{meta}{title} ||= trim $h1->all_text;
  $h1->remove;
}

sub _get_cached_document {
  my ($self, $file) = @_;
  return undef if $ENV{CONVOS_CMS_NO_CACHE};

  my $doc   = $self->_cache->get("$file");
  my $mtime = $file->stat->mtime;
  return $doc if $doc and $doc->{mtime} == $mtime;
}

sub _parse_document {
  my ($self, $file, $params) = @_;

  my $doc = {
    after_content  => '',
    before_content => '',
    custom_css     => '',
    excerpt        => '',
    meta           => {},
    mtime          => $file->stat->mtime,
  };

  my ($body, $FH) = ('', $file->open);
  while (readline $FH) {
    $_ = decode 'UTF-8', $_;
    $body .= $_ and last  if $. == 1 and !/^---/;    # meta header has to start with "---"
    last                  if $. > 1 and /^---/;      # meta header stops with "----"
    $doc->{meta}{$1} = $2 if /^\s*(\w+)\s*:\s*(.+)/;
  }

  $body .= $_ while readline $FH;
  $body = Mojo::DOM->new(decode 'UTF-8', $body);
  $self->_parse_markdown($body, $doc);
  $self->_rewrite_document($body, $doc) unless $params->{scan};
  $self->_extract_excerpt($body, $doc);
  $self->_extract_heading($body, $doc);

  my $dt = dt $file->basename =~ m!(\d{4}-\d{2}-\d{2})! ? "${1}T00:00:00" : $doc->{mtime};
  $doc->{ts} = $dt->epoch;
  $doc->{meta}{name} = $file->basename;
  $doc->{meta}{name} =~ s!^\d{4}-\d{2}-\d{2}-!!;
  $doc->{meta}{name} =~ s!\.md$!!;
  $doc->{meta}{$_}    ||= $dt->$_ for qw(mday mon year);
  $doc->{meta}{date}  ||= sprintf '%s. %s, %s', $dt->mday, $dt->month, $dt->year;
  $doc->{meta}{title} ||= $file->basename;
  $doc->{path} = "$file";
  $self->_cache->set("$file" => $doc);

  return $doc;
}

sub _parse_markdown {
  my ($self, $dom) = @_;

  $dom->find('[markdown]')->each(sub {
    my $tag      = shift;
    my $markdown = $tag->content;
    my $indent   = $markdown =~ s!^([ ]+)!!m ? $1 : '';
    $markdown =~ s!^$indent!!mg;
    $tag->content($self->_md->markdown($markdown));
  });

  $dom->child_nodes->each(sub {
    my $tag = shift;
    $tag->replace($self->_md->markdown($tag->content))
      if $tag->type eq 'text'
      or $tag->type eq 'raw';
  });

  $dom->find('p:empty')->each('remove');
}

sub _perldoc {
  my ($self, $c, $pod) = @_;
  my $dom = Mojo::DOM->new(_perldoc_to_html($pod));
  my $doc = {body => $dom, meta => {}};

  my $base_url = $c->url_for('/doc/');
  $_->{href} =~ s!^https://metacpan\.org/pod/!$base_url! and $_->{href} =~ s!::!/!gi
    for $dom->find('a[href]')->map('attr')->each;

  my @toc;
  $dom->find('h1, h2, h3')->each(sub {
    my $tag = shift;
    $tag->{id} = slugify(trim $tag->all_text);

    if ($tag->{id} eq 'name' and $tag->next and $tag->next->tag eq 'p') {
      my $next = $tag->next;
      $next->tag('h1');
      $tag->remove;
    }
    else {
      $tag->tag('h' . ($1 + 1)) if $tag->tag =~ m!(\d+)!;
      push @toc, [trim($tag->all_text), $tag->{id}, []] if $tag->tag eq 'h2';
      push @{$toc[-1][2]}, [trim($tag->all_text), $tag->{id}, []] if @toc and $tag->tag eq 'h3';
    }
  });

  for my $e ($dom->find('pre > code')->each) {
    next if (my $str = $e->content) =~ /^\s*(?:\$|Usage:)\s+/m;
    next unless $str =~ /[\$\@\%]\w|-&gt;\w|^use\s+\w/m;
    my $attrs = $e->attr;
    my $class = $attrs->{class};
  }

  $dom->find('p:empty')->each('remove');
  $self->_extract_excerpt($dom, $doc);
  $self->_extract_heading($dom, $doc);
  $doc->{toc} = \@toc;

  return $doc;
}

# Heavily inspired by Mojolicious::Plugin::MojoDocs
sub _perldoc_to_html {
  my ($pod) = @_;
  my $parser = Pod::Simple::XHTML->new;
  $parser->perldoc_url_prefix('https://metacpan.org/pod/');
  $parser->$_('') for qw(html_header html_footer);
  $parser->anchor_items(1);
  $parser->strip_verbatim_indent(sub {
    (sort map {/^(\s+)/} @{shift()})[0];
  });
  $parser->output_string(\(my $output));
  return $@ unless eval { $parser->parse_string_document("$pod"); 1 };
  return $output;
}

sub _rewrite_href {
  my ($self, $c, $md) = @_;

  for my $section (grep { $md->{$_} } qw(after_content before_content body)) {
    next unless $md->{$section};
    $md->{$section}->find('a[href^="/"]')->each(sub { $_[0]->{href} = $c->url_for($_[0]->{href}) });
    $md->{$section}->find('img[src^="/"]')->each(sub { $_[0]->{src} = $c->url_for($_[0]->{src}) });
  }
}

sub _rewrite_document {
  my ($self, $dom, $doc) = @_;

  my @toc;
  $dom->find('h1, h2, h3')->each(sub {
    my $tag = shift;
    $tag->{id} ||= slugify(trim $tag->all_text);
    return if $tag->tag eq 'h1';
    push @toc, [trim($tag->all_text), $tag->{id}, []] if $tag->tag eq 'h2';
    push @{$toc[-1][2]}, [trim($tag->all_text), $tag->{id}, []] if @toc and $tag->tag eq 'h3';
  });

  $dom->find('img[alt="fas"], img[alt="fab"]')->each(sub {
    my $tag = shift;
    $tag->tag('i');
    $tag->{class} = join ' ', delete $tag->{alt}, 'fa-' . delete $tag->{src};
  });

  $dom->find('pre')->each(sub {
    my $tag      = shift;
    my $pre_text = $tag->all_text;
    $pre_text =~ s![\r\n]+$!!s;
    $tag->content($pre_text);
  });

  $dom->find('style:not(.inline)')->each(sub {
    my $tag = shift;
    $doc->{custom_css} .= $tag->all_text . "\n";
    $tag->remove;
  });

  $dom->find('.is-after-content, .is-before-content')->each(sub {
    my $tag = shift;
    my $key = $tag->attr('class') =~ /is-after/ ? 'after_content' : 'before_content';
    $doc->{$key} .= "$tag";
    $tag->remove;
  });

  $doc->{custom_css} =~ s!</?\w+>!!g;    # Remove <p> tags inside <style>
  $doc->{body}           = $dom;
  $doc->{after_content}  = $doc->{after_content}  ? Mojo::DOM->new($doc->{after_content})  : undef;
  $doc->{before_content} = $doc->{before_content} ? Mojo::DOM->new($doc->{before_content}) : undef;
  $doc->{toc}            = \@toc;
}

sub _scan_for_blogs_p {
  my ($self, $app) = @_;

  return Mojo::IOLoop->subprocess->run_p(sub {
    my @blogs;
    for my $year ($app->core->home->child(qw(content blog))->list({dir => 1})->each) {
      return unless $year->basename =~ m!^(\d{4})$!;
      push @blogs, $year->list->map(sub { $self->_parse_document(shift, {scan => 1}) })->each;
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
