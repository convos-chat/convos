#!perl
use lib '.';
use t::Helper;

my $t = t::Helper->t_selenium;
t::Helper->t_selenium_register($t);

note 'Go to unknown conversation';
my $join_btn      = '.messages-container .btn';
my $too_cool_path = '/chat/irc-convos/%23too_cool';
$t->navigate_ok($too_cool_path)->wait_for('.messages-container')->live_text_is($join_btn, 'Yes')
  ->live_text_is('.messages-container a[href="/chat"]', 'No');

note 'Join #too_cool';
$t->click_ok($join_btn)->wait_for('a.message__from');

note 'Open up settings for #too_cool and leave conversation';
my $leave_btn     = qq(.sidebar-left .form-actions .btn.for-sign-out-alt);
my $convos_link   = qq(.sidebar-left a[href="/chat/irc-convos/%23convos"]);
my $too_cool_link = qq(.sidebar-left a[href="$too_cool_path"]);
$t->click_ok(qq($too_cool_link i))->wait_for($leave_btn);
$t->click_ok($leave_btn)->wait_for(qq($convos_link.has-path));

note 'Open up settings for #convos and leave conversation';
$t->click_ok(qq($convos_link i))->wait_for($leave_btn);
$t->click_ok($leave_btn)->wait_for(qq(a[href="/settings/conversation"].has-path));

note 'Add conversation dialog';
$t->send_keys_ok('main [name="dialog_id"]', '#too_cool')->click_ok('main .btn.for-comment')
  ->wait_for($too_cool_link);

note 'Part with command';
$t->click_ok($too_cool_link)->wait_for('#chat_input')->send_keys_ok('#chat_input', '/part ')
  ->click_ok('.chat-input__send')->wait_for(qq(a[href="/settings/conversation"].has-path));

note 'Close connection';
my $delete_btn = '.sidebar-left .form-actions .btn.for-trash';
$t->click_ok(qq(a[href="/chat/irc-convos"] i))->wait_for($delete_btn);
$t->click_ok($delete_btn)->wait_for(qq(a[href="/settings/connection"].has-path))
  ->live_text_is('.sidebar-left a[href="/settings/connection"] span', 'No conversations');

done_testing;
