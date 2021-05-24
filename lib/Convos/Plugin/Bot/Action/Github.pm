package Convos::Plugin::Bot::Action::Github;
use Mojo::Base 'Convos::Plugin::Bot::Action';

use Convos::Util qw(DEBUG);
use List::Util qw(any);
use Mojo::File qw(path);

has description => 'Send messages based on GitHub events.';

sub register {
  my ($self, $bot, $config) = @_;
  my $class = ref $self;
  my $user  = $bot->user;

  Scalar::Util::weaken($user);
  $self->on(
    webhook_github => sub {
      my ($self, $event, $payload) = @_;

      return DEBUG && warn qq([GitHub] Action cannot handle event $event.\n)
        unless my $method = $self->can("_github_event_$event");

      my $repo_name    = $payload->{repository}{full_name}                 || 'default';
      my $repositories = $self->config->get("/action/$class/repositories") || {};
      return DEBUG && warn qq([GitHub] Action has no config for $repo_name.\n)
        unless my $rules = $repositories->{$repo_name};

      for my $rule (@$rules) {
        next unless any { $_ eq $event } @{$rule->{events} || []};
        next unless my ($connection_id, $conversation_id) = @{$rule->{to}};

        my $connection = $user->get_connection($connection_id);
        next unless $connection and $connection->state eq 'connected';
        next unless my $message = $self->$method($rule, $payload);

        $connection->send_p($conversation_id, $message)->catch(sub {
          $user->core->log->warn(sprintf 'Bot sent "%s": %s', $message, pop);
        });
      }
    }
  );
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
      - events: [ fork, issues, milestone, pull_request, star ]
        to: [ 'irc-localhost', '#convos' ]

=head1 DESCRIPTION

L<Convos::Plugin::Bot::Action::Github> is enables L<Convos> to receive
and act on GitHub webhooks.

=head1 ATTRIBUTES

=head2 description

See L<Convos::Plugin::Bot::Action/description>.

=head1 METHODS

=head2 register

Starts listening to the "webhook_github" event.

=head1 SEE ALSO

L<Convos::Plugin::Bot>.

=cut
