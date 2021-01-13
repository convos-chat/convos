#!perl
use lib '.';
use t::Helper;

$ENV{CONVOS_BACKEND} = 'Convos::Core::Backend';
my $t = t::Helper->t;

note 'defaults';
$t->get_ok('/')->element_exists('html[lang="en"]')->text_is('title', 'Better group chat - Convos');

note 'dummy translation';
my $dict = $t->app->i18n->dictionary('no');
$dict->{lang}          = 'no';
$dict->{Autocomplete}  = 'Autofullføring';
$dict->{'%1 - Convos'} = '%1 - Convos test translation';

$t->get_ok('/', {'Accept-Language' => 'no'})->element_exists('html[lang="no"]');
$t->get_ok('/', {'Accept-Language' => 'en;q=0.5,no'})->element_exists('html[lang="no"]');
$t->get_ok('/', {'Accept-Language' => 'no-nb,en'})->element_exists('html[lang="no"]')
  ->text_is('title', 'Better group chat - Convos test translation');

done_testing;
