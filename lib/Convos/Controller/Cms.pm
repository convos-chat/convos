package Convos::Controller::Cms;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::File 'path';
use Pod::Simple::Search;

sub blog_entry {
  my $self  = shift;
  my $stash = $self->stash;
  my ($year, $mon, $mday, $name) = @$stash{qw(year mon mday name)};
  my @path = ('blog', $year, sprintf '%04s-%02s-%02s-%s', $year, $mon, $mday, $name);

  return $self->cms->document_p(\@path)->then(sub {
    my $doc = shift;
    return $self->reply->not_found unless $doc->{body};
    $self->_meta_to_social($doc->{meta});
    $self->_render_doc(blog_entry => $doc);
  });
}

sub blog_list {
  my $self = shift;

  return $self->cms->blogs_p({page => $self->param('p')})->then(sub {
    my $blogs = shift;
    $_->{meta}{url} = $self->url_for('blog_entry', $_->{meta})->to_abs for @$blogs;
    $self->res->headers->remove('X-Provider-Name');
    $self->render('blog_list', blogs => $blogs);
  });
}

sub doc {
  my $self = shift;
  my @path = ('doc', split '/', $self->stash('file'));
  $path[-1] = sprintf 'index.%s', $self->stash('format') || 'html' if $path[-1] eq 'index';

  return $self->cms->document_p(\@path)->then(sub {
    my $doc = shift;
    $self->stash(format => $doc->{format})               if $doc->{format};
    return $self->redirect_to($doc->{meta}{redirect_to}) if $doc->{meta}{redirect_to};
    return $self->_render_doc(cms => $doc)               if $doc->{body};

    shift @path;    # remove "doc"
    my $format = $path[-1] =~ s!\.(txt|yaml)$!! ? $1 : 'html';
    $self->stash(format => $format);

    my $module       = join '::', @path;
    my $metacpan_url = "https://metacpan.org/pod/$module";
    $self->stash(module => $module);
    $self->social(canonical => $metacpan_url) unless $module =~ m!^Convos!;

    my $path = $ENV{CONVOS_CMS_PERLDOC}
      && Pod::Simple::Search->new->find($module, map { $_, "$_/pods" } @INC);
    return $self->_render_perldoc($path) if $path and -r $path;

    return $self->redirect_to($metacpan_url) if $module =~ m![A-Z]!;
    return $self->reply->not_found;
  });
}

sub index {
  my $self   = shift;
  my $format = $self->stash('format') || 'html';

  return $self->cms->document_p(["index.$format"])->then(sub {
    my $doc = shift;
    return $self->_render_doc(cms => $doc) if $doc->{body};
    return $self->render('app');
  });
}

sub _meta_to_social {
  my ($self, $meta) = @_;
  $self->title($meta->{title});
  $self->social($_ => $meta->{$_})
    for grep { defined $meta->{$_} } qw(canonical description image url);
  $meta->{image} = $self->url_for($meta->{image})->to_abs if $meta->{image};
}

sub _render_doc {
  my ($self, $template, $doc) = @_;
  $self->_meta_to_social($doc->{meta});
  $self->res->headers->remove('X-Provider-Name');
  $self->render($template, custom_css => $doc->{custom_css}, doc => $doc);
}

sub _render_perldoc {
  my ($self, $path) = @_;
  my $src = path($path)->slurp;

  $self->respond_to(
    txt  => {data => $src},
    yaml => sub {
      my $doc = $self->cms->perldoc($src);
      $doc->{body} = $src;
      $self->render('perldoc', doc => $doc);
    },
    html => sub {
      my $doc  = $self->cms->perldoc($src);
      my $meta = $doc->{meta};
      $self->res->headers->remove('X-Provider-Name');
      $self->title($meta->{title});
      $self->social(description => $meta->{description}) if $meta->{description};
      $self->render('perldoc', doc => $doc);
    }
  );
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Cms - Convos CMS actions

=head1 DESCRIPTION

L<Convos::Controller::Cms> is a L<Mojolicious::Controller> with
CMS related actions.

=head1 ATTRIBUTES

=head2 cms_home

  $path = $c->cms_home;

Returns the path to "$CONVOS_HOME/content".

=head1 METHODS

=head2 blog_entry

Render a single blog post provided by the user.

  $CONVOS_HOME/content/blog/2020/2020-05-23-some-title.md

=head2 blog_list

Shows a list of all the blogs in C<$CONVOS_HOME/content/blog>.

=head2 doc

Render documents provided by the user or from "assets".

  $CONVOS_HOME/content/whatever.md
  $CONVOS_HOME/content/.../whatever.md

=head2 index

Renders an index file provided by the user or the Convos web app.

  $CONVOS_HOME/content/index.md

=head1 SEE ALSO

L<Convos>.

=cut
