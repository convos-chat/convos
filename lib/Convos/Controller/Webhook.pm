package Convos::Controller::Webhook;
use Mojo::Base 'Mojolicious::Controller';

use List::Util qw(any);
use Mojo::JSON qw(false true);
use Mojo::Util qw(network_contains);

# https://github.blog/changelog/2019-04-09-webhooks-ip-changes/
our @GITHUB_WEBHOOK_NETWORKS = split ',',
  ($ENV{GITHUB_WEBHOOK_NETWORKS} // '140.82.112.0/20,192.30.252.0/22');

sub github {
  my $self = shift->openapi->valid_input or return;

  return $self->reply->errors('Unable to accept webhook request.', 503)
    unless my $bot = eval { $self->bot };

  my $remote_address = $self->tx->remote_address;
  return $self->reply->errors("Invalid source IP $remote_address.", 403)
    unless any { network_contains $_, $remote_address } @GITHUB_WEBHOOK_NETWORKS;

  my $event_name = $self->req->headers->header('X-GitHub-Event');
  my @actions    = $bot->emit_all(webhook_github => $event_name, $self->req->json);
  $self->render(openapi => {delivered => int @actions ? true : false});
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Webhook - Convos webhooks

=head1 DESCRIPTION

L<Convos::Controller::Webhook> is a L<Mojolicious::Controller> with
webhook related actions.

=head1 METHODS

=head2 github

See L<https://convos.chat/api.html#op-post--webhookgithub>

=head1 SEE ALSO

L<Convos>.

=cut
