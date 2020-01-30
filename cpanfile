# You can install this projct with curl -L http://cpanmin.us | perl - https://github.com/jhthorsen/convos/archive/master.tar.gz
requires "IO::Socket::SSL"                => "2.009"; # Need to installed first, so "cpanm -M" works
requires "Crypt::Eksblowfish"             => "0.009";
requires "File::HomeDir"                  => "1.00";
requires "File::ReadBackwards"            => "1.05";
requires "IRC::Utils"                     => "0.12";
requires "JSON::Validator"                => "3.16";
requires "LinkEmbedder"                   => "1.11";
requires "Mojolicious"                    => "8.25";
requires "Mojolicious::Plugin::OpenAPI"   => "2.18";
requires "Mojolicious::Plugin::Webpack"   => "0.12";
requires "Parse::IRC"                     => "1.20";
requires "Time::Piece"                    => "1.20";
requires "Unicode::UTF8"                  => "0.62";

suggests "Cpanel::JSON::XS"  => "4.09";
suggests "EV"                => "4.0";
suggests "IO::Socket::Socks" => "0.64";

on develop => sub {
  requires "Test::Deep"                 => "0.11";
  requires "Test::Mojo::Role::Selenium" => "0.09";
  requires "Test::More"                 => "0.88";
};

test_requires "Test::Deep" => "0.11";
test_requires "Test::More" => "0.88";
