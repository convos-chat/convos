# You can install this projct with curl -L http://cpanmin.us | perl - https://github.com/jhthorsen/convos/archive/master.tar.gz
requires "Crypt::Eksblowfish"                => "0.009";
requires "File::HomeDir"                     => "1.00";
requires "File::ReadBackwards"               => "1.05";
requires "Mojo::IOLoop::ForkCall"            => "0.17";
requires "Mojo::IRC"                         => "0.28";
requires "Mojolicious"                       => "6.40";
requires "Mojolicious::Plugin::AssetPack"    => "0.70";
requires "Mojolicious::Plugin::LinkEmbedder" => "0.2301";
requires "Parse::IRC"                        => "1.20";
requires "Swagger2"                          => "0.75";

test_requires "Test::Deep" => "0.11";
test_requires "Test::More" => "0.88";
