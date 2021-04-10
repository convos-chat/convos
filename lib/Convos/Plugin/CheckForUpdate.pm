package Convos::Plugin::CheckForUpdate;
use Mojo::Base 'Convos::Plugin';

use JSON::Validator::Util qw(E);
use Mojo::JSON qw(false true);
use Scalar::Util qw(looks_like_number);

sub register {
  my ($self, $app, $config) = @_;
  $app->helper(check_for_update_p => \&_check_for_update_p);
  Mojo::IOLoop->recurring(60 => sub { _maybe_check_for_update($app) });
}

sub _maybe_check_for_update {
  my $app = @_;

  my $settings = $app->core->settings;
  return unless my $interval = $settings->check_for_update->{interval};
  return if $settings->check_for_update->{last_checked} > time - $interval;

  $app->check_for_update_p->then(sub {
  })->catch(sub {
    $app->log->warn(sprintf 'check_for_update: %s', shift);
  });
}

sub _check_for_update_p {
  my ($c, $params) = @_;

  my $url      = $ENV{CONVOS_CHECK_FOR_UPDATE} // 'https://convos.chat/api/version';
  my $settings = $c->app->core->settings;
  return Mojo::Promise->resolve({disabled => true}) unless $url =~ m!^(http|/)!;

  $url = Mojo::URL->new($url)->query({app_id => $settings->app_id, running => $c->app->VERSION});
  return $c->ua->get_p($url)->then(sub {
    my $tx = shift;
    warn Mojo::Util::dumper($tx->res->json);

    #return if $res->{available_version} eq $settings->check_for_update->{available_version};
    #$settings->check_for_update->{available_version} = $res->{available_version};
    #$settings->check_for_update->{last_checked}      = time;
    return $settings->save_p;
  });
}

1;
