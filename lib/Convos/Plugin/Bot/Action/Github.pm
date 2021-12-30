package Convos::Plugin::Bot::Action::Github;
use Mojo::Base 'Convos::Plugin::Bot::Action';

use List::Util qw(any);
use Mojo::File qw(path);

has description => 'Send messages based on GitHub events.';

sub handle_webhook_github_event {
  my ($self, $headers, $payload) = @_;
  return unless $self->enabled;

  my $event  = $headers->header('X-GitHub-Event') || 'unknown';
  my $method = $self->can("_github_event_$event");
  return unless $method;

  my $class        = ref $self;
  my $repo_name    = $payload->{repository}{full_name}                 || 'default';
  my $repositories = $self->config->get("/action/$class/repositories") || {};
  return unless my $rules = $repositories->{$repo_name};

  my @status;
  for my $rule (@$rules) {
    next unless my ($connection_id, $conversation_id) = split '/', +($rule->{to} || ''), 2;

    push @status,
      {connection_id => $connection_id, conversation_id => $conversation_id, error => ''};
    $status[-1]{error} = "Unwanted event $event.", next
      unless any { $_ eq $event } @{$rule->{events} || []};

    my $connection = $self->bot->user->get_connection($connection_id);
    $status[-1]{error} = 'Not connnected.', next
      unless $connection and $connection->state eq 'connected';
    $status[-1]{error} = 'No message generated.', next
      unless my $message = $self->$method($rule, $payload);

    $connection->send_p($conversation_id, $message)->catch(sub {
      $self->user->core->log->warn(sprintf 'Bot sent "%s": %s', $message, pop);
    });
  }

  return {status => \@status};
}

sub _github_event_create {
  my ($self, $rule, $payload) = @_;

  return unless $payload->{ref_type} eq 'tag';
  return sprintf '%s created %s %s in %s - %s/tree/%s', $payload->{sender}{login},
    $payload->{ref_type}, $payload->{ref}, $payload->{repository}{name},
    $payload->{repository}{html_url}, $payload->{ref};
}

sub _github_event_fork {
  my ($self, $rule, $payload) = @_;

  return sprintf '%s forked %s - %s', $payload->{sender}{login}, $payload->{repository}{name},
    $payload->{forkee}{html_url};
}

sub _github_event_issues {
  my ($self, $rule, $payload) = @_;

  my $action = $payload->{action};
  return unless any { $action eq $_ } qw(closed opened reopened);

  return sprintf '%s %s issue #%s in %s: %s - %s', $payload->{sender}{login}, $action,
    $payload->{issue}{number}, $payload->{repository}{name}, $payload->{issue}{title},
    $payload->{issue}{html_url};
}

sub _github_event_milestone {
  my ($self, $rule, $payload) = @_;

  my $action = $payload->{action};
  return unless any { $action eq $_ } qw(closed created opened);

  return sprintf '%s %s milestone #%s in %s: %s - %s', $payload->{sender}{login}, $action,
    $payload->{milestone}{number}, $payload->{repository}{name}, $payload->{milestone}{title},
    $payload->{milestone}{html_url};
}

sub _github_event_pull_request {
  my ($self, $rule, $payload) = @_;

  my $action = $payload->{action};
  return unless any { $action eq $_ } qw(closed opened reopened);

  return sprintf '%s %s pull request #%s in %s: %s - %s', $payload->{sender}{login}, $action,
    $payload->{pull_request}{number}, $payload->{repository}{name},
    $payload->{pull_request}{title},  $payload->{pull_request}{html_url};
}

sub _github_event_star {
  my ($self, $rule, $payload) = @_;
  return unless $payload->{action} eq 'created';
  return sprintf '%s starred %s - %s', $payload->{sender}{login}, $payload->{repository}{name},
    $payload->{sender}{html_url};
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Bot::Action::Github - Act on GitHub webhooks

=head1 SYNOPSIS

=head2 Config file

  ---
  actions:
  - class: Convos::Plugin::Bot::Action::Github
    repositories:
      'convos-chat/convos':
      - events: [ create, fork, issues, milestone, pull_request, star ]
        to: 'irc-localhost/#convos'

=head2 Github webhook config

Github have to be configured to send webhooks to Convos.

=over 2

=item * Payload URL

"Payload URL" must be sent to the
L<https://convos.chat/api.html#op-post--webhook--provider_name-> endpoint, with
"provider_name" set to "github". Example:

  https://convos.example.com/api/webhook/github

=item * Content type

"Content type" must be set to "application/json".

=item * Secret

"Secret" can be left blank since Convos will check C<CONVOS_WEBHOOK_NETWORKS>
for a valid source IP instead.

Note: This might change in the future.

=item * Which events would you like to trigger this webhook?

Supported triggers are currently: "Branch or tag creation", "Forks", "Issues",
"Milestones", "Pull requests" and "Stars". You can however just send "anything"
since the bot will filter out the supported "events".

=back

=head1 DESCRIPTION

L<Convos::Plugin::Bot::Action::Github> is enables L<Convos> to receive
and act on GitHub webhooks.

=head1 ATTRIBUTES

=head2 description

See L<Convos::Plugin::Bot::Action/description>.

=head1 METHODS

=head2 handle_webhook_github_event

  my $res = $action->handle_webhook_github_event($event_name, $payload);

Will try to render a message based on a GitHub event and payload.

=head1 SEE ALSO

L<Convos::Plugin::Bot>.

=cut
