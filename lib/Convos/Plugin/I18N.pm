package Convos::Plugin::I18N;
use Mojo::Base 'Convos::Plugin';

use HTTP::AcceptLanguage;
use Mojo::Date;
use Mojo::File qw(path);
use Mojo::Util qw(decode);

use constant CAPTURE => $ENV{CONVOS_I18N_CAPTURE_LEXICONS} && 1;
use constant RELOAD  => $ENV{CONVOS_RELOAD_DICTIONARIES}   && 1;

has _dictionaries => sub { +{} };
has _meta         => sub { +{} };

sub register {
  my ($self, $app, $config) = @_;

  $app->helper('i18n.dictionary'        => sub { $self->_dictionaries->{$_[1]} });
  $app->helper('i18n.load_dictionaries' => sub { $self->_load_dictionaries(shift, @_) });
  $app->helper('i18n.meta' => sub { $_[1] ? $self->_meta->{$_[1]} || {} : $self->_meta });
  $app->helper('l'         => \&_l);
  $app->hook(around_action => sub { $self->_around_action(@_) });

  $app->i18n->load_dictionaries;
}

sub _around_action {
  my ($self, $next, $c, $action, $last) = @_;
  return $next->() unless $last;

  my $dictionaries = $self->_dictionaries;
  my $lang
    = $c->param('lang') || $c->js_session('lang') || $c->req->headers->accept_language || 'en';
  my $dict;
  for my $l (HTTP::AcceptLanguage->new($lang)->languages) {
    my ($prefix) = split /-/, $l;
    ($dict, $lang) = ($dictionaries->{$l},      $l)      and last if $dictionaries->{$l};
    ($dict, $lang) = ($dictionaries->{$prefix}, $prefix) and last if $dictionaries->{$prefix};
  }

  ($dict, $lang) = ($dictionaries->{en}, 'en') unless $dict;
  $c->i18n->load_dictionaries($lang) if RELOAD;
  $c->stash(dictionary => $dict, lang => $lang);
  $next->();
}

sub _load_dictionaries {
  my ($self, $c, $load_lang) = @_;
  my $meta = $self->_meta;
  my $now  = Mojo::Date->new->to_datetime;

  my @files = map { $_->list->each }
    ($c->app->home->child(qw(assets i18n)), $c->app->core->home->child('i18n'));

  for my $file (@files) {
    next unless $file =~ m!([\w-]+)\.po$!;

    my $lang = $1;
    next if $load_lang and $load_lang ne $lang;

    my $dictionary = $self->_dictionaries->{$lang} ||= {};
    _parse_po_file($file->realpath, sub { $dictionary->{$_[0]{msgid}} = $_[0]{msgstr} });

    my $h = delete($dictionary->{''}) // '';
    for (split /\n/, $h) {
      my ($key, $value) = split /:\s+/, $_, 2;
      $value =~ s!;\s*$!!;
      $key   =~ s!-!_!g;
      $meta->{$lang}{lc $key} = $value;
    }

    for my $k (qw(po_revision_date pot_creation_date)) {
      $meta->{$lang}{$k} ||= $now;
      $meta->{$lang}{$k} =~ s!\s!T!;
    }

    $meta->{$lang}{content_type}         ||= 'text/plain; charset=UTF-8';
    $meta->{$lang}{language_team}        ||= "$lang <lang\@convos.chat>";
    $meta->{$lang}{mime_version}         ||= '1.0';
    $meta->{$lang}{project_id_version}   ||= $Convos::VERSION;
    $meta->{$lang}{report_msgid_bugs_to} ||= 'https://github.com/convos-chat/convos/issues';

    my $n = int keys %$dictionary;
    $c->log->debug(qq(Loaded $n lexicons for dictionary "$lang" from $file.));
  }
}

sub _parse_po_file {
  my $cb = pop;
  my $PO = shift->open;
  my ($entry, $section, @comments) = ({}, '');

  my $cb_maybe = sub {
    return unless defined $entry->{msgid} and $entry->{msgstr};
    $entry->{comments} = \@comments;
    $cb->($entry);
    ($entry, $section, @comments) = ({}, '');
  };

  while (<$PO>) {
    s![\r\n]!!g;
    $_ = decode 'UTF-8', $_;

    if (/^\s*#/ and !$entry->{msgid}) {
      $cb_maybe->();
      $section = '';
      push @comments, $1 if /^\s*#:\s*(.+)/;
    }
    elsif (s!^\s*msgid!!) {
      $cb_maybe->();
      $section = 'msgid';
    }
    elsif (s!^\s*msgstr!!) {
      $section = 'msgstr';
    }

    if ($section) {
      $entry->{$section} //= '';
      $entry->{$section} .= _unescape($1) if /(['"].*)/;
    }
  }

  # process last translation
  $cb_maybe->();
}

sub _l {
  my ($c, $lexicon, @args) = @_;
  _log($lexicon) if CAPTURE;
  $lexicon = $c->stash->{dictionary}{$lexicon} || $lexicon;
  $lexicon =~ s!%(\d+)!{$args[$1 - 1] // $1}!ge;
  return $lexicon;
}

sub _log {
  my $lexicon = shift;
  return unless state $file = -w 'local' && path('local/capture.po');
  my @caller = caller(2);
  my $FH     = $file->open('>>');
  $caller[1] =~ s!^template\s*!!;
  print {$FH} "$caller[1]:$caller[2]:$lexicon\n";
}

sub _unescape {
  local $_ = $_[0];
  s!^['"]!! and s!['"]$!!;
  s!\\"!"!g;
  s!\\n!\n!g;
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

  $c->i18n->load_dictionaries($lang);
  $c->i18n->load_dictionaries; # load all

Used to find available dictionaries (.po) files, parse them and build internal
structures.

=head1 METHODS

=head2 register

Used to register the L</HELPERS> and a "before_dispatch" hook which will detect
user language from the "Accept-Language" header.

=head1 SEE ALSO

L<Convos>.

=cut
