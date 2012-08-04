use lib 'lib';
use Test::More;
eval 'use Test::Compile; 1' or plan skip_all => 'Test::Compile required';
all_pm_files_ok();
