use t::Helper;

my $irc = Mojo::IRC->new(server => 'irc.example.com');
my $form;

{
  no warnings 'redefine';
  *Mojo::IRC::connect = sub { $irc = shift; Mojo::IOLoop->stop; };
  $t->app->core->start;
}

$form = {login => 'fooman', email => 'foobar@barbar.com', password => 'barbar', password_again => 'barbar'};
$t->post_ok('/register' => form => $form)->status_is('302')->header_is('Location', '/wizard');

$form
  = {wizard => 1, server => 'chat.freenode.net:6697', nick => 'ice_cool', username => 'batman', password => 's3cret'};
$t->post_ok('/connection/add', form => $form)->status_is('302')->header_is('Location', '/freenode');

{
  Mojo::IOLoop->timer(2 => sub { Mojo::IOLoop->stop; });
  Mojo::IOLoop->start if $irc->server ne 'chat.freenode.net:6697';
  is_deeply $irc->tls, {}, 'tls';
  is $irc->nick,   'ice_cool',               'nick';
  is $irc->pass,   's3cret',                 'pass';
  is $irc->server, 'chat.freenode.net:6697', 'server';
  is $irc->user,   'batman',                 'user';
}

done_testing;
