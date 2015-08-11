# You can install this projct with curl -L http://cpanmin.us | perl - https://github.com/jhthorsen/convos/archive/master.tar.gz
requires "Crypt::Eksblowfish"             => "0.009";
requires "File::HomeDir"                  => "1.00";
requires "File::ReadBackwards"            => "1.05";
requires "Mojo::IRC"                      => "0.26";
requires "Mojolicious"                    => "6.14";
requires "Mojolicious::Plugin::AssetPack" => "0.58";
requires "Mojolicious::Plugin::Riotjs"    => "0.03";
requires "Parse::IRC"                     => "1.20";
requires "Swagger2"                       => "0.47";

test_requires "Test::Deep" => "0.11";
test_requires "Test::More" => "0.88";
