#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

note 'defaults';
$t->get_ok('/')->element_exists('html[lang="en"]')->text_is('title', 'Better group chat - Convos')
  ->text_is('h2', 'Loading...');
$t->get_ok('/api/i18n/en.json')->status_is(200)
  ->json_is('/dictionary/Autocomplete', 'Autocomplete');

note 'dummy translation';
my $dict = $t->app->i18n->dictionary('no');
$dict->{lang}          = 'no';
$dict->{Autocomplete}  = 'Autofullføring';
$dict->{'Loading...'}  = 'Laster...';
$dict->{'%1 - Convos'} = '%1 - Convos test translation';

$t->get_ok('/', {'Accept-Language' => 'no'})->element_exists('html[lang="no"]');
$t->get_ok('/', {'Accept-Language' => 'en;q=0.5,no'})->element_exists('html[lang="no"]');
$t->get_ok('/', {'Accept-Language' => 'no-nb,en'})->element_exists('html[lang="no"]')
  ->text_is('title', 'Better group chat - Convos test translation')->text_is('h2', 'Laster...');

$t->get_ok('/api/i18n/no.json')->status_is(200)
  ->json_is('/dictionary/Autocomplete', 'Autofullføring');

note 'spanish';
$t->get_ok('/', {'Accept-Language' => 'es-MX,es;q=0.8,en-US;q=0.5,en;q=0.3'})
  ->element_exists('html[lang="es"]')->text_is('h2', 'Cargando...');

$t->get_ok('/api/i18n/es.json')->status_is(200)->json_is('/dictionary/Email', 'Correo electrónico');

done_testing;
