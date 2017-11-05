package Convos::Command::ident;

use Mojo::Base 'Mojolicious::Command';

sub log { shift->app->log }

sub reply {
  my ($self, $reply) = @_;
  $self->log->info("Indent reply: $reply");
  print "$reply\015\012";
}

sub run {
  $| = 1;
  my $cmd = shift;
  my $request = do { local $/ = "\015\012"; <STDIN> };
  $self->log->info("Ident request $request");

  my ($local, $remote);
  if ($request =~ /^\s*(\d+)\s*,\s*(\d+)\s*$/) {
    $local = $1; $remote = $2;
  } else {
    return $self->reply("$request : ERROR : INVALID-PORT");
  }

  if ($local < 1 || $local > 65535 || $remote < 1 || $remote > 65535) {
    return $self->reply("$request : ERROR : INVALID-PORT");
  }

  for my $user (@{ $cmd->app->core->users }) {
    for my $conn (@{ $user->connections }) {
      my ($name, $pass) = @{ $conn->_userinfo };
      next unless $name;
      next unless $local  == $conn->{me}{sockport};
      next unless $remote == $conn->url->port;
      return $self->reply("$request : USERID : OTHER : $name");
    }
  }

  return $self->reply("$request : ERROR : NO-USER");
}

1;

