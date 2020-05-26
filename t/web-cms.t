#!perl
use lib '.';
use t::Helper;

$ENV{MOJO_MODE} = 'production';
my $t = t::Helper->t;

note 'bundled doc';
$t->get_ok('/doc/nope')->status_is(404)->element_exists('h1')->text_is('h1', 'Not Found (404)');

note 'default index file';
$t->get_ok('/')->status_is(200)->element_exists('.welcome-screen__about');

note 'custom index file';
my $cms_dir = $t->app->core->home->child('content');
$cms_dir->make_path;
$cms_dir->child('index.md')->spurt("# Custom index\n\nToo cool for school!\n");
$t->get_ok('/')->status_is(200)->element_exists('body.for-cms')
  ->element_exists('body.for-cms main.cms-content')->text_is('title', 'Custom index - Convos')
  ->text_is('h1', 'Custom index')->text_like('main.cms-content p', qr{Too cool for school});

note 'empty blog index';
$t->get_ok('/blog')->status_is(200)->element_exists('body.for-cms')
  ->element_exists('main.cms-content')->text_like('main p', qr{is empty});

note 'blog too-cool';
$t->get_ok('/blog/2020/5/17/too-cool.html')->status_is(404);
$cms_dir->child(qw(blog 2020))->make_path;
$cms_dir->child(qw(blog 2020 2020-05-17-too-cool.md))->spurt(<<"HERE");
---
title: Cool title
heading: Cool heading
---
## Cool sub title
This blog is about
some cool stuff.

## Cool other title
And then some!

<div class="is-before-content">Is before content.</div>
<div class="is-after-content">Is after content.</div>
<style>
body {
  background: red;
}
</style>
HERE

$t->get_ok('/blog/2020/5/17/too-cool.html')->status_is(200)->element_exists('article.cms-content')
  ->text_is('title', 'Cool title - Convos')->text_is('h1', 'Cool heading')
  ->element_exists('body.for-cms')
  ->text_like('article.cms-content p', qr{This blog is about.*some cool stuff}s)
  ->text_like('head > style',          qr{background: red})->text_unlike('head > style', qr{<p>})
  ->text_is('body > .is-before-content', 'Is before content.')
  ->text_is('body > .is-after-content',  'Is after content.');

note 'blog index';
$t->get_ok('/blog')->status_is(200)->element_exists('main')
  ->element_exists('main section.blog-list__item')->text_is('section h2', 'Cool heading')
  ->text_is('section .cms-date a', '17. May, 2020')
  ->text_like('section .cms-excerpt', qr{This blog is about.*some cool stuff.}s)
  ->text_is('section .cms-more a', 'Read more');

done_testing;
