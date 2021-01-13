package Convos::Plugin::I18N;
use Mojo::Base 'Convos::Plugin';

use HTTP::AcceptLanguage;
use Mojo::File qw(path);
use Mojo::Util qw(decode);

has _dictionaries => sub { +{} };

sub register {
  my ($self, $app, $config) = @_;

  $app->helper('i18n.dictionary'        => sub { $self->_dictionary(@_) });
  $app->helper('i18n.languages'         => sub { [sort keys %{$self->_dictionaries}] });
  $app->helper('i18n.load_dictionaries' => sub { $self->_load_dictionaries(shift->app) });
  $app->helper('l'                      => \&_l);
  $app->hook(before_dispatch => sub { $self->_before_dispatch(@_) });

  $app->i18n->load_dictionaries;
}

sub _before_dispatch {
  my ($self, $c) = @_;

  my $dictionaries = $self->_dictionaries;
  my $lang         = HTTP::AcceptLanguage->new($c->req->headers->accept_language || 'en');
  my $dict;
  for my $lang ($lang->languages) {
    my ($prefix) = split /-/, $lang;
    $dict = $dictionaries->{$lang} || $dictionaries->{$prefix} and last;
  }

  $dict ||= $dictionaries->{en};
  $c->stash(dictionary => $dict, lang => $dict->{lang});
}

sub _dictionary {
  my ($self, $c, $lang) = @_;
  return $self->_dictionaries->{$lang} ||= {lang => $lang};
}

sub _load_dictionaries {
  my ($self, $app) = @_;
  my $dictionaries = $self->_dictionaries;

  for my $file (map { path($_, 'i18n')->list->each } $app->asset->assets_dir) {
    next unless $file =~ m!([\w-]+)\.po$!;
    my $lang = $1;
    _parse_po_file($file, sub { $dictionaries->{$lang}{$_[0]->{msgid}} = $_[0]->{msgstr} });
    $dictionaries->{$lang}{lang} = $lang;
  }
}

sub _parse_po_file {
  my $cb    = pop;
  my $PO    = shift->open;
  my $entry = {};
  while (<$PO>) {
    s![\r\n]!!g;
    $_                     = decode 'UTF-8', $_;
    @$entry{qw{file line}} = ($1, $2)     if /^#:\s*([^:]+):(\d+)/;
    $entry->{$1}           = _unquote($2) if /(msgid|msgstr)\s*(['"].*)/;
    next unless $entry->{msgid} and $entry->{msgstr};
    $cb->($entry);
    $entry = {};
  }
}

sub _l {
  my ($c, $lexicon, @args) = @_;
  $lexicon = $c->stash->{dictionary}{$lexicon} || $lexicon;
  $lexicon =~ s!%(\d+)!{$args[$1 - 1] // $1}!ge;
  return $lexicon;
}

sub _unquote {
  local $_ = $_[0];
  s!^['"]!! and s!['"]$!!;
  return $_;
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::I18N - Internationalization plugin for Convos

=head1 DESCRIPTION

L<Convos::Plugin::I18N> is a plugin for Convos to do translations.

=head1 HELPERS

=head2 i18n.dictionary

  $c->i18n->dictionary($lang);

Used to retrieve a dictionary for a given language.

=head2 i18n.languages

  $array_ref = $c->i18n->languages;

Used to retrieve a list of available languages.

=head2 l

  $str = $c->l($lexicon, @variables);

Will translate a C<$lexicon> and replace C<$1>, C<$2>, ... variables in the
string with C<@variables>.

=head2 i18n.load_dictionaries

  $c->i18n->load_dictionaries;

Used to find available dictionaries (.po) files, parse them and build internal
structures.

=head1 METHODS

=head2 register

Used to register the L</HELPERS> and a "before_dispatch" hook which will detect
user language from the "Accept-Language" header.

=head1 SEE ALSO

L<Convos>.

=cut
