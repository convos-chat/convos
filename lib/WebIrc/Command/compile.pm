package WebIrc::Command::compile;

=head1 NAME

WebIrc::Command::compile - Compile assets

=head1 DESCRIPTION

This web_irc command creates "compiled.js" and "compiled.css" in the public
directory.

=head1 ENVIRONMENT VARIABLES

=head2 SASS_BIN

Defaults to the first "sass" file found in PATH.

=head2 YUI_COMPRESSOR_BIN

Defaults to the first "yuicompressor" or "yui-compressor" file found in PATH.

=cut

use Mojo::Base 'Mojolicious::Command';
use Mojo::Util 'slurp';
use Mojo::DOM;

unless($ENV{SASS_BIN} //= '') {
  for(split /:/, $ENV{PATH} || '') {
    next unless -e "$_/sass"; # -e because it might be a symlink
    $ENV{SASS_BIN} = "$_/sass";
    last;
  }
}

unless($ENV{YUI_COMPRESSOR_BIN} //= '') {
  for(split /:/, $ENV{PATH} || '') {
    # -e because it might be a symlink
    $ENV{YUI_COMPRESSOR_BIN} = "$_/yuicompressor", last if -e "$_/yuicompressor"; # installed from npm
    $ENV{YUI_COMPRESSOR_BIN} = "$_/yui-compressor", last if -e "$_/yui-compressor";
  }
}

=head1 ATTRIBUTES

=head2 description

Returns a description about this command.

=head2 usage

Returns a string describing how to use this command.

=cut

has description => "Creates public/compiled.js and public/compiled.css\n";
has usage => <<"EOF";
usage: $0 compile
EOF

=head1 METHODS

=head2 run

Calls L</compile_javascript> and L</compile_stylesheet>.

=cut

sub run {
  my($self, @args) = @_;

  $self->compile_javascript;
  $self->compile_stylesheet;
}

=head2 compile_javascript

Creates "public/compiled.js" from the list of js files inside the default template.
Will also minify that file using L</YUI_COMPRESSOR_BIN> if it exists.

=cut

sub compile_javascript {
  my $self = shift;
  my $args = { template => 'empty', layout => 'default', title => '', VERSION => 0 };
  my $app = $self->app;
  my $mini = $app->home->rel_file('public/compiled.js');
  my $mode = $app->mode;
  my $output;

  $app->mode('compiling');
  ($output) = $app->renderer->render(Mojolicious::Controller->new(app => $app), $args);
  $app->mode($mode);
  $output = Mojo::DOM->new($output);

  unless($ENV{YUI_COMPRESSOR_BIN}) {
    $app->log->warn("YUI_COMPRESSOR_BIN is missing, cannot create $mini");
    return $self;
  }

  open my $COMPILED, '>', $mini;
  $output->find('script')->each(sub {
    my $file = $app->home->rel_file("public$_[0]->{src}");
    return print $COMPILED slurp $file if $file =~ m!/minified/!;
    $app->log->info("$ENV{YUI_COMPRESSOR_BIN} $file -o /tmp/min.js");
    system $ENV{YUI_COMPRESSOR_BIN} => $file => -o => "/tmp/min.js";
    print $COMPILED slurp "/tmp/min.js";
  });
  unlink '/tmp/min.js';
  close $COMPILED;

  $self;
}

=head2 compile_stylesheet

Creates "public/compiled.css" from "public/sass/main.scss", using L</SASS_BIN>
if it possible.

=cut

sub compile_stylesheet {
  my $self = shift;
  my $file = $self->app->home->rel_file('public/sass/main.scss');
  my $mini = $self->app->home->rel_file('public/compiled.css');

  unless($ENV{SASS_BIN}) {
    $self->app->log->warn("SASS_BIN is missing, cannot create $mini");
    return $self;
  }

  $self->app->log->info("$ENV{SASS_BIN} $file $mini --style compressed");
  system $ENV{SASS_BIN} => $file => $mini => '--style', 'compressed' if $ENV{SASS_BIN};
  return $self;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
