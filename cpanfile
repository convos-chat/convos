# You can install dependencies with ./script/convos install [--all|--prod]
requires "IO::Socket::SSL"                => "2.009"; # Need to installed first, so "cpanm -M" works
requires "Crypt::Passphrase"              => "0.003";
requires "Crypt::Passphrase::Argon2"      => "0.003";
requires "Crypt::Passphrase::Bcrypt"      => "0.001";
requires "File::HomeDir"                  => "1.00";
requires "File::ReadBackwards"            => "1.05";
requires "HTTP::AcceptLanguage"           => "0.02";
requires "IRC::Utils"                     => "0.12";
requires "LinkEmbedder"                   => "1.20";
requires "Module::Install"                => "1.10"; # required by Text::MultiMarkdown
requires "Mojolicious"                    => "9.20";
requires "Mojolicious::Plugin::OpenAPI"   => "4.02";
requires "Mojolicious::Plugin::Syslog"    => "0.06";
requires "Mojolicious::Plugin::Webpack"   => "1.01";
requires "Parse::IRC"                     => "1.22";
requires "Text::Markdown::Hoedown"        => "1.03";
requires "Time::Piece"                    => "1.20";
requires "Unicode::UTF8"                  => "0.62";

suggests "Cpanel::JSON::XS"  => "4.09";
suggests "EV"                => "4.0";
suggests "IO::Socket::Socks" => "0.64";

feature 'bot', 'Convos bot' => sub {
  requires 'DBD::SQLite'        => "1.66";
  requires 'Hailo'              => "0.75";
  requires 'Math::Calc::Parser' => "1.00";
};

feature 'ldap', 'LDAP user management' => sub {
  requires 'Net::LDAP' => "0.68";
};

test_requires "Test::Deep" => "0.11";
test_requires "Test::More" => "0.88";
