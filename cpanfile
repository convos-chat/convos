requires 'File::Slurp'     => 0;
requires 'IRC::Utils'      => 0.12;
requires 'List::MoreUtils' => 0;
requires 'Mojo::IRC'       => 0.03;
requires 'Mojolicious'     => 4.30;
requires 'Mojo::Redis'     => 0.9916;
requires 'Parse::IRC'      => 1.18;
requires 'Time::Piece'     => 1.20;
requires 'Unicode::UTF8'   => 0.58;
    
on 'develop' => sub {
  # AssetPack and optional deps
  recommends 'Mojolicious::Plugin::AssetPack' => '0.01';
  recommends 'JavaScript::Minifier::XS' => 0.09;
  recommends 'CSS::Minifier::XS' => 0.08;
};

