package WebIrc::Command::compile;

=head1 NAME

WebIrc::Command::compile - Compile assets

=head1 DESCRIPTION

This web_irc command creates "compiled.js" and "compiled.css" in the public
directory.

=head1 ENVIRONMENT VARIABLES

=head2 LESSC_BIN

Defaults to the first "lessc" file found in PATH.

=head2 YUI_COMPRESSOR_BIN

Defaults to the first "yui-compressor" file found in PATH.

=cut

use Mojo::Base 'Mojolicious::Command';
use Mojo::DOM;

unless($ENV{LESSC_BIN} //= '') {
  for(split /:/, $ENV{PATH} || '') {
    next unless -e "$_/lessc"; # -e because it might be a symlink
    $ENV{LESSC_BIN} = "$_/lessc";
    last;
  }
}

unless($ENV{YUI_COMPRESSOR_BIN} //= '') {
  for(split /:/, $ENV{PATH} || '') {
    next unless -e "$_/yui-compressor"; # -e because it might be a symlink
    $ENV{YUI_COMPRESSOR_BIN} = "$_/yui-compressor";
    last;
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
  my $app = $self->app;
  my $args = { template => 'empty', layout => 'default', title => '', VERSION => 0 };
  my $compiled = $app->home->rel_file('public/compiled.js');
  my $modified = +(stat $compiled)[9] || 0;
  my $mode = $app->mode;
  my $js = '';
  my($output, $format);

  $app->mode('compiling');
  ($output, $format) = $app->renderer->render(Mojolicious::Controller->new(app => $app), $args);
  $app->mode($mode);
  $output = Mojo::DOM->new($output);

  $output->find('script')->each(sub {
    my $file = $app->home->rel_file("public" . $_[0]->{src});
    $file = $self->_minify_javascript($file, $modified);
    $app->log->debug("Compiling $file");
    open my $JS, '<', $file or die "Read $file: $!";
    while(<$JS>) {
      m!^\s*//! and next;
      m!^\s*(.+)! or next;
      $js .= "$1\n";
    }
  });

  open my $COMPILED, '>', $compiled or die "Write $compiled: $!";
  print $COMPILED $js;
}

=head2 compile_stylesheet

Creates "public/compiled.css" from "public/less/main.less", using
L</LESSC_BIN> and L</YUI_COMPRESSOR_BIN> if they exists

=cut

sub compile_stylesheet {
  my $self = shift;
  my $less_file = $self->app->home->rel_file('public/less/main.less');
  my $css_file = $self->app->home->rel_file('public/compiled.css');

  system $ENV{LESSC_BIN} => -x => $less_file => $css_file if $ENV{LESSC_BIN};
  system $ENV{YUI_COMPRESSOR_BIN} => $css_file => -o => $css_file if $ENV{YUI_COMPRESSOR_BIN};
}

sub _minify_javascript {
  my($self, $file, $compiled_modified) = @_;
  my $mini = $file =~ s!/js/!/minified/!r; # ! st2 hack
  my $modified = +(stat $file)[9] || -1;

  return $file if $mini eq $file;
  return $mini if $modified < $compiled_modified;
  system $ENV{YUI_COMPRESSOR_BIN} => $file => -o => $mini if $ENV{YUI_COMPRESSOR_BIN};
  return -e $mini ? $mini : $file;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
