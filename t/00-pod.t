use lib 'lib';
use Test::More;
eval 'use Test::Pod; 1' or plan skip_all => 'Test::Pod required';
all_pod_files_ok();
