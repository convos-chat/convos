package Convos::Controller::Search;

use Mojo::Base 'Mojolicious::Controller';

my $has_rg=!system('which rg > /dev/null');

sub messages {
    my $self = shift->openapi->valid_input or return;
    my $user = $self->backend->user        or return $self->unauthorized;

    $query{$_} = $self->param($_) for grep { defined $self->param($_) } qw(limit match);

    $self->delay(
        sub { $user->messages_all(\%query, shift->begin) },
        sub {
            my ($delay, $err, $messages) = @_;
            die $err if $err;
            $self->render(openapi => {messages => $messages});
        },
    );
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::Search - Convos search

=head1 DESCRIPTION

L<Convos::Controller::Search> is a L<Mojolicious::Controller> with
search related actions.

=head1 METHODS

=head2 messages

See L<Convos::Manual::API/searchMessages>.

=head1 SEE ALSO

L<Convos>.

=cut
