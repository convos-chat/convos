# You can install this projct with curl -L http://cpanmin.us | perl - https://github.com/jhthorsen/convos/archive/master.tar.gz
requires "Crypt::Eksblowfish"             => "0.009";
requires "File::HomeDir"                  => "1.00";
requires "Mojo::IRC"                      => "0.22";
requires "Mojolicious"                    => "5.70";
requires "Mojolicious::Plugin::AssetPack" => "0.55";
requires "Mojolicious::Plugin::Riotjs"    => "0.03";
requires "Parse::IRC"                     => "1.20";
requires "Swagger2"                       => "0.27";

test_requires "Test::Deep" => "0.11";
test_requires "Test::More" => "0.88";
