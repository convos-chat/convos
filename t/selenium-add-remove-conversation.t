#!perl
use lib '.';
use t::Helper;

my $t = t::Helper->t_selenium;
t::Helper->t_selenium_register($t);

my $join_btn      = '.main.is-above-chat-input .btn';
my $too_cool_path = '/chat/irc-convos/%23too%2Fcool';
my $leave_btn     = qq(.sidebar-left .form-actions .btn.for-sign-out-alt);
my $convos_link   = qq(.sidebar-left a[href="/chat/irc-convos/%23convos"]);
my $too_cool_link = qq(.sidebar-left a[href="$too_cool_path"]);

subtest 'Go to unknown conversation' => sub {
  $t->navigate_ok($too_cool_path)->wait_for('.main.is-above-chat-input')
    ->live_text_is($join_btn,                                   'Yes')
    ->live_text_is('.main.is-above-chat-input a[href="/chat"]', 'No');
};

subtest 'Join #too/cool' => sub {
  $t->click_ok($join_btn)->wait_for('a.message__from');
};

subtest 'Open up settings for #too/cool and leave conversation' => sub {
  $t->click_ok(qq($too_cool_link i))->wait_for($leave_btn);
  $t->click_ok($leave_btn)->wait_for(qq($convos_link.has-path));
};

subtest 'Open up settings for #convos and leave conversation' => sub {
  $t->click_ok(qq($convos_link i))->wait_for($leave_btn);
  $t->click_ok($leave_btn)->wait_for(qq(a[href="/settings/conversation"].has-path));
};

subtest 'Add conversation conversation' => sub {
  $t->send_keys_ok('main [name="conversation_id"]', '#too/cool')->click_ok('main .btn.for-comment')
    ->wait_for($too_cool_link);
};

subtest 'Part with command' => sub {
  $t->click_ok($too_cool_link)->wait_for('.is-primary-input')
    ->send_keys_ok('.is-primary-input', '/part ')->click_ok('.chat-input__send')
    ->wait_for(qq(a[href="/settings/conversation"].has-path));
};

subtest 'Close connection' => sub {
  my $delete_btn = '.sidebar-left .form-actions .btn.for-trash';
  $t->click_ok(qq(a[href="/chat/irc-convos"] i))->wait_for($delete_btn);
  $t->click_ok($delete_btn)->wait_for(qq(a[href="/settings/connections"].has-path))
    ->live_text_is('.sidebar-left a[href="/settings/connections"] span', 'No conversations');
};

done_testing;
