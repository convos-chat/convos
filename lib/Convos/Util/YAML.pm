package Convos::Util::YAML;
use Mojo::Base -strict;

use Exporter qw(import);
use YAML::XS ();

our @EXPORT_OK = qw(decode_yaml encode_yaml);

sub decode_yaml { local $YAML::XS::Boolean = 'JSON::PP'; YAML::XS::Load(shift) }
sub encode_yaml { local $YAML::XS::Boolean = 'JSON::PP'; YAML::XS::Dump(shift) }

1;

=encoding utf8

=head1 NAME

Convos::Util::YAML - Decode and encode YAML

=head1 SYNOPSIS

  use Convos::Util::YAML qw(decode_yaml encode_yaml);

=head1 FUNCTIONS

=head2 decode_yaml

  $any = decode_yaml($utf8);

=head2 encode_yaml

  $utf8 = decode_yaml($any);

=head1 SEE ALSO

L<Convos>.

=cut
