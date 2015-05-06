use Mojo::Base -strict;
use Convos::Model;
use Test::More;

my @cleanup;

if ($ENV{TEST_ONLINE}) {
  my $model = Convos::Model->new;
  ok -d $model->share_dir, 'default CONVOS_SHARE_DIR';
  like $model->share_dir, qr{\W+\.local\W+share\W+convos$}, 'HOME/.local/share/convos';
  push @cleanup, $model->share_dir;
}

{
  local $ENV{CONVOS_SHARE_DIR} = 'convos-test-model-share-dir';
  my $model = Convos::Model->new;
  ok -d $model->share_dir, 'local CONVOS_SHARE_DIR';
  is $model->share_dir, Cwd::abs_path('convos-test-model-share-dir'), 'absolute path to convos-test-model-share-dir';
  push @cleanup, $model->share_dir;
}

rmdir $_ for @cleanup;

done_testing;
