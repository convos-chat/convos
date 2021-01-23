#!perl
BEGIN { $ENV{CONVOS_RELOAD_DICTIONARIES} = 1 }
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

note 'defaults';
$t->get_ok('/')->element_exists('html[lang="en"]')->text_is('title', 'Better group chat - Convos')
  ->text_is('h2', 'Loading...');
$t->get_ok('/api/i18n/en.json')->status_is(200)
  ->json_is('/available_languages/en/language_team', 'English <lang-en@convos.chat>')
  ->json_is('/available_languages/es/language_team', 'Española <lang-es@convos.chat>')
  ->json_is('/available_languages/it/language_team', 'Italiana <lang-it@convos.chat>')
  ->json_is('/available_languages/no/language_team', 'Norsk <lang-no@convos.chat>')
  ->json_is('/dictionary/Autocomplete',              'Autocomplete');
$t->get_ok('/', {'Accept-Language' => ''})->element_exists('html[lang="en"]');
$t->get_ok('/', {'Accept-Language' => 'x,y,z'})->element_exists('html[lang="en"]');

note 'italian';
$t->get_ok('/', {'Accept-Language' => 'it-ch'})->element_exists('html[lang="it"]')
  ->text_is('h2', 'Caricamento in corso...');
$t->get_ok('/api/i18n/it.json')->status_is(200)
  ->json_is('/dictionary/User email', 'Email dell\'utente');

note 'norwegian';
$t->get_ok('/', {'Accept-Language' => 'no'})->element_exists('html[lang="no"]');
$t->get_ok('/', {'Accept-Language' => 'en;q=0.5,no'})->element_exists('html[lang="no"]');
$t->get_ok('/', {'Accept-Language' => 'no-nb,en'})->element_exists('html[lang="no"]')
  ->text_is('h2', 'Laster...');

$t->get_ok('/api/i18n/no.json')->status_is(200)->json_is('/dictionary/Autocomplete', 'Autofullfør');

note 'spanish';
$t->get_ok('/', {'Accept-Language' => 'es-MX,es;q=0.8,en-US;q=0.5,en;q=0.3'})
  ->element_exists('html[lang="es"]')->text_is('h2', 'Cargando...');
$t->get_ok('/api/i18n/es.json')->status_is(200)
  ->json_is('/dictionary/User email', 'Correo electrónico');

note 'reload';
my @reloaded;
$t->app->helper('i18n.load_dictionaries' => sub { push @reloaded, pop });
$t->get_ok('/')->get_ok('/', {'Accept-Language' => 'no'})->get_ok('/?lang=it')
  ->get_ok('/api/i18n/es.json');
is_deeply \@reloaded, [qw(en no it es)], 'reloaded languages' or diag join ', ', @reloaded;

done_testing;
