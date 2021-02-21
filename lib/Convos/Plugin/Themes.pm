package Convos::Plugin::Themes;
use Mojo::Base 'Convos::Plugin';

use Mojo::File 'path';

has _themes_list => sub { +[] };
has _themes_map  => sub { +{} };

sub register {
  my ($self, $app, $config) = @_;

  $app->helper('themes.detect' => sub { $self->_detect(shift->app) });
  $app->helper('themes.get'    => sub { $self->_get(@_) });
  $app->helper('themes.list'   => sub { $self->_themes_list });
  $app->helper('themes.serve'  => sub { $self->_serve(shift) });
  $app->routes->get('/themes/:theme')->to(cb => sub { $_[0]->themes->serve(@_) });

  Mojo::IOLoop->recurring($ENV{CONVOS_DETECT_THEMES_INTERVAL} || 10, sub { $app->themes->detect });
  $app->themes->detect;
}

sub _detect {
  my ($self, $app) = @_;
  my (@list, %map);

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

    $id           ||= lc $name;
    $color_scheme ||= 'normal';
    $map{$id}{name}  = $name;
    $map{$id}{title} = $name;
    $map{$id}{title} .= " ($color_scheme)" unless $color_scheme eq 'normal';
    $map{$id}{urls}{$color_scheme} = sprintf '/themes/%s?v=%s', $file->basename, $app->VERSION;

    push @{$map{$id}{variants}}, $color_scheme;
    push @list,
      {
      id       => "${color_scheme}-${id}",
      name     => $name,
      scheme   => $color_scheme,
      title    => $map{$id}{title},
      variants => $map{$id}{variants},
      url      => $map{$id}{urls}{$color_scheme},
      };
  };

  $read_theme->($_) for map { path($_, 'themes')->list->each } @{$app->static->paths};

  my $user_themes = path($app->config('home'), 'themes');
  $user_themes->make_path unless -d $user_themes;
  $read_theme->($_) for $user_themes->list->each;

  for my $theme (values %map) {
    next if $theme->{urls}{normal};
    $theme->{urls}{normal} = +(sort { $b cmp $a } values %{$theme->{urls}})[0];
  }

  $self->_themes_list(\@list)->_themes_map(\%map);
}

sub _get {
  my ($self, $c) = (shift, shift);

  my $id     = shift                     || 'convos';
  my $theme  = $self->_themes_map->{$id} || $self->_themes_map->{convos};
  my $scheme = shift;
  $scheme = (keys %{$theme->{urls}})[0] if !$scheme or $scheme eq 'auto';

  return {
    %$theme,
    id    => "$scheme-$id",
    url   => $scheme && $theme->{urls}{$scheme} || $theme->{urls}{normal},
    title => "$theme->{name} ($scheme)",
  };
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
L<bundled|https://github.com/convos-chat/convos/tree/master/public/themes> with
Convos, but you can also create your own custom themes. The custom themes must
be placed in
L<$CONVOS_HOME/themes|https://convos.chat/doc/config#convos_home>. The
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
L<https://github.com/convos-chat/convos/blob/master/assets/sass/_variables.scss>
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

  $theme = $c->themes->get("my-theme");
  $theme = $c->themes->get("my-theme", "dark");
  $theme = $c->themes->get("my-theme", "light");

Used to get information about a single theme.

=head2 themes.serve

  $c->themes->serve("/themes/convos_color-scheme-light.css?v=4.03");

This method can serve a given theme by path. Will probably get redesigned to
take C<$name>, C<$color_scheme> instead.

=head1 METHODS

=head2 register

  $app->plugin("Convos::Plugin::Themes");

Called when this plugin is registered in the C<Mojolicious> application.

=head1 SEE ALSO

L<Convos>.

=cut
