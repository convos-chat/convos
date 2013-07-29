use warnings;
use strict;
use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('WebIrc');

{
  my $r = $t->app->routes;
  my $templates = $t->app->home->list_files('templates/event');
  my %stash = (
    action_message => { sender => 'other_person', avatar => 'https://gravatar.com/abc', highlight => 1 },
    message => { sender => 'other_person', avatar => 'https://gravatar.com/abc', highlight => 1 },
    nick_change => { old_nick => 'old', new_nick => 'doe' },
    rpl_namreply => { nicks => [ { mode => '@', nick => 'random' } ] },
    topic => { topic => 'Cool topic' },
    whois_channels => { channels => [qw/ #wirc #mojo /] },
    whois => { realname => 'John doe', host => 'wirc.pl', user => 'user@wir.pl' },
  );

  for(@$templates) {
    my $e = s!.html.ep!!r; # ! st2 hack
    $r->get("/event/$e")->to(
      cid => 1,
      message => 'Too cool!',
      nick => 'doe',
      status => 200,
      target => '#yikes',
      template => "event/$e",
      timestamp => 1375085961,
      %{ $stash{$e} || {} },
    );

    $t->get_ok("/event/$e")->status_is(200);
  }
}

done_testing;
