package Convos::Plugin::Themes;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File 'path';

has _themes => sub { +{} };

sub register {
  my ($self, $app, $config) = @_;

  $app->helper('themes.detect'  => sub { $self->_detect(shift->app) });
  $app->helper('themes.get'     => sub { $self->_get(@_) });
  $app->helper('themes.serve'   => sub { $self->_serve(shift) });
  $app->helper('themes.url_for' => sub { $self->_url_for(@_) });
  $app->routes->get('/themes/:theme')->to(cb => sub { $_[0]->themes->serve(@_) });

  Mojo::IOLoop->recurring($ENV{CONVOS_DETECT_THEMES_INTERVAL} || 10, sub { $app->themes->detect });
  $app->themes->detect;
}

sub _detect {
  my ($self, $app) = @_;
  my $themes = {};

  my $read_theme = sub {
    return unless $_[0] =~ m!\.css$!;

    my $file = shift;
    my $fh   = $file->open;
    my ($id, $name, $color_scheme) = ('', '', '');

    while (my $line = readline $fh) {
      $color_scheme ||= $1 if $line =~ m!\Wcolor-scheme:\s*(\S+)!i;
      $name         ||= $1 if $line =~ m!\Wname:\s*(\S+)!i;
      last if $color_scheme and $name;
    }

    unless ($name) {
      $name = $file->basename;
      $name =~ s!\.css$!!;
    }

    $id                      ||= lc $name;
    $color_scheme            ||= 'default';
    $themes->{$id}{variants} ||= {};
    $themes->{$id}{variants}{$color_scheme} = sprintf '/themes/%s?v=%s', $file->basename,
      $app->VERSION;
    $themes->{$id}{name} = $name;
  };

  $read_theme->($_) for map { path($_, 'themes')->list->each } @{$app->static->paths};

  my $user_themes = path($app->config('home'), 'themes');
  $user_themes->make_path unless -d $user_themes;
  $read_theme->($_) for $user_themes->list->each;

  for my $theme (values %$themes) {
    next if $theme->{variants}{default};
    $theme->{variants}{default} = +(sort { $b cmp $a } values %{$theme->{variants}})[0];
  }

  $self->_themes($themes);
}

sub _get {
  my ($self, $c, $name) = @_;
  return @_ == 2 ? $self->_themes : $self->_themes->{$name};
}

sub _serve {
  my ($self, $c) = @_;
  my $theme = $c->param('theme');

  for my $path ($c->app->core->home, @{$c->app->static->paths}) {
    my $file = Mojo::File->new($path, themes => "$theme.css");
    return $c->reply->file($file) if -e $file;
  }

  return $c->render(text => "/* $theme.css not found */\n", status => 404);
}

sub _url_for {
  my ($self, $c, $name, $color_scheme) = @_;
  return undef unless my $theme = $self->_get($c, $name || '');
  $color_scheme ||= 'default';
  return $c->url_for($theme->{variants}{$color_scheme} || $theme->{variants}{default});
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Themes - A plugin for serving themes

=head1 DESCRIPTION

L<Convos::Plugin::Themes> is a L<Convos::Plugin> for finding and serving themes
either bundled with Convos or defined by the user.

Themes will be looked up when L<Convos> is started, as well as on an interval
while running. This means that if a new theme is created, then it should be
available in the web gui after just some seconds.

There are multiple themes
L<bundled|https://github.com/Nordaaker/convos/tree/master/public/themes> with
Convos, but you can also create your own custom themes. The custom themes must
be placed in
L<$CONVOS_HOME/themes|https://convos.by/doc/config.html#convos_home>. The
default location is:

  $HOME/.local/share/convos/themes/

There are no real requirements to the content of the file (except of being
valid CSS), but it is highly suggested to add the following header:

  /*
   * name: Your-Cool-Theme
   * color-scheme: dark
   */

The "color-scheme" is only useful if you have both a "light" and a "dark"
version of the theme. The filename will be completely ignored if the header
exist, so you can name the file whatever you want.

The rest of the file should mostly contain variable definitions.
L<https://github.com/Nordaaker/convos/blob/master/assets/sass/_variables.scss>
shows the available variables that you can override. Here is an example of a
custom theme that will look the same as the default "Convos" light theme, but
will have a much bigger font size.

  /*
   * name: I-Like-Big-Text-And-I-Cannot-Lie
   * color-scheme: light
   */

  :root {
    --font-size: 24px;
  }

Here is another example, where the theme is based on the default dark
version of Convos:

  /*
   * name: I-Like-Big-Text-And-I-Cannot-Lie
   * color-scheme: dark
   */

  @import './convos_color-scheme-dark.css?v=4.03';

  :root {
    --font-size: 24px;
  }

=head1 HELPERS

=head2 themes.detect

  $c->themes->detect;

Will detect which themes that are available. This method is called every
C<CONVOS_DETECT_THEMES_INTERVAL> seconds, which defaults to 10.

=head2 themes.get

  $single = $c->themes->get("my-theme");
  $all    = $c->themes->get;

Used to get information about a single theme or all the themes.

=head2 themes.serve

  $c->themes->serve("/themes/convos_color-scheme-light.css?v=4.03");

This method can serve a given theme by path. Will probably get redesigned to
take C<$name>, C<$color_scheme> instead.

=head2 themes.url_for

  $path = $c->themes->url_for($name, $color_scheme);
  $path = $c->themes->url_for("my-theme");
  $path = $c->themes->url_for("my-theme", "light");

Returns a relative path for the URL, with a version number to avoid cache
issues. Example:

  /themes/convos_color-scheme-light.css?v=4.03

=head1 METHODS

=head2 register

  $app->plugin("Convos::Plugin::Themes");

Called when this plugin is registered in the C<Mojolicious> application.

=head1 SEE ALSO

L<Convos>.

=cut
