#!perl
use lib '.';
use t::Helper;

my $t = t::Helper->t_selenium;

my $signup_btn  = '#signup .btn.for-save';
my $signin_btn  = '#signin .btn.for-sign-in-alt';
my $logout_link = '.sidebar-left a[href*="logout"]';

subtest 'first user signup' => sub {
  $t->wait_for('#signup')->live_element_exists_not('#signin')
    ->live_element_exists_not('#signup .error')->live_element_exists('#signup [name=email]')
    ->live_element_exists('#signup [name=password]');

  $t->click_ok($signup_btn)->wait_for('#signup .error')
    ->live_text_like('#signup .error', qr{email}i);

  $t->send_keys_ok('#signup [name=email]', 'jhthorsen@cpan.org');
  $t->click_ok($signup_btn)->wait_for(0.2)->wait_for('#signup .error')
    ->live_text_like('#signup .error', qr{password}i);

  $t->send_keys_ok('#signup [name=password]', 'superduper');
  $t->click_ok($signup_btn)->wait_for(0.2)->wait_for('.main.is-above-chat-input');
};

subtest 'showing the correct chat after login' => sub {
  $t->live_element_exists('a.for-conversation.has-path');
};

subtest 'logout' => sub {
  $t->wait_for($logout_link)->click_ok($logout_link)->wait_for('#signin');
};

subtest 'signup disabled' => sub {
  $t->wait_for('#signin')->live_element_exists_not('#signup [name=email]')
    ->live_element_exists_not('#signup [name=password]')->live_element_exists('#signin')
    ->live_element_exists('#signin [name=email]')->live_element_exists('#signin [name=password]');
};

subtest 'login' => sub {
  $t->click_ok($signin_btn)->wait_for('#signin .error')
    ->live_text_like('#signin .error', qr{email}i);

  $t->send_keys_ok('#signin [name=email]',    'jhthorsen@cpan.org');
  $t->send_keys_ok('#signin [name=password]', 'Superduper');
  $t->click_ok($signin_btn)->wait_for(0.2)->wait_for('#signin .error')
    ->live_text_like('#signin .error', qr{password}i);

  $t->send_keys_ok('#signin [name=password]', [(\'backspace') x 10]);
  $t->send_keys_ok('#signin [name=password]', 'superduper');
  $t->click_ok($signin_btn)->wait_for(0.2)->wait_for('.main.is-above-chat-input');
};

subtest 'change settings' => sub {
  my $settings_link  = '.sidebar-left a[href$="/settings"]';
  my $open_to_public = '#convos-settings [for=form_open_to_public]';
  my $save_btn       = '#convos-settings .form-actions .btn';
  $t->wait_for($settings_link)->click_ok($settings_link)->wait_for($open_to_public);
  $t->driver->execute_script("document.querySelector('$save_btn').scrollIntoView()");
  $t->click_ok($open_to_public)->click_ok($save_btn);
};

subtest 'login and signup' => sub {
  $t->click_ok($logout_link)->wait_for('#signin');
  $t->wait_for('#signin')->live_element_exists('#signin [name=email]')
    ->live_element_exists('#signin [name=password]')->live_element_exists('#signup [name=email]')
    ->live_element_exists('#signup [name=password]');
};

# $t->wait_for(120);
# note $t->driver->get_page_source;

done_testing;
