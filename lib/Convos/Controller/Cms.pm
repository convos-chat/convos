package Convos::Controller::Cms;
use Mojo::Base 'Mojolicious::Controller';

sub blog_entry {
  my $self  = shift;
  my $stash = $self->stash;
  my ($year, $mon, $mday, $name) = @$stash{qw(year mon mday name)};
  my @path = ('blog', $year, sprintf '%04s-%02s-%02s-%s', $year, $mon, $mday, $name);

  return $self->cms->document_p(\@path)->then(sub {
    my $doc = shift;
    return $self->reply->not_found unless $doc->{body};
    return $self->_render_doc(blog_entry => $doc);
  });
}

sub blog_list {
  my $self = shift;

  return $self->cms->blogs_p({page => $self->param('p')})->then(sub {
    my $blogs = shift;
    $_->{meta}{url} = $self->url_for('blog_entry', $_->{meta})->to_abs for @$blogs;
    $self->render('blog_list', blogs => $blogs, for_cms => 1);
  });
}

sub doc {
  my $self = shift;
  my @path = ('doc', split '/', $self->stash('file'));
  push @path, 'index' if @path == 1;

  return $self->cms->document_p(\@path)->then(sub {
    my $doc = shift;
    return $self->redirect_to($doc->{redirect_to}) if $doc->{redirect_to};
    return $self->reply->not_found unless $doc->{body};
    return $self->_render_doc(cms => $doc);
  });
}

sub index {
  my $self = shift;

  return $self->cms->document_p(['index'])->then(sub {
    my $doc = shift;
    return $self->render('index', load_user => 1) unless $doc->{body};
    return $self->_render_doc(cms => $doc);
  });
}

sub _render_doc {
  my ($self, $template, $doc) = @_;

  my $meta = $doc->{meta};
  $self->title(join ' - ', $meta->{title}, $self->settings('organization_name'));
  $self->social($_ => $meta->{$_})
    for grep { defined $meta->{$_} } qw(canonical description image url);

  $self->render($template, custom_css => $doc->{custom_css}, doc => $doc, for_cms => 1);
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
