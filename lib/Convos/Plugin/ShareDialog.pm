package Convos::Plugin::ShareDialog;
use Mojo::Base 'Convos::Plugin';

use Convos::Util 'E';
use Mojo::JSON qw(false true);
use Mojo::Util qw(sha1_sum steady_time);

has _shared => sub { +{} };

sub register {
  my ($self, $app, $config) = @_;

  $self->add_backend_helpers($app);
  $app->config->{settings}{share_dialog} = 1;
  push @{$app->renderer->classes}, __PACKAGE__;

  my $shared = ($app->share_dialog->load || {})->{shared} || {};
  $self->_shared($shared);
  $app->helper('share_dialog.shared' => sub {$shared});

  # Render web page. Note that "dialog_id" is just here to help the visitor.
  # The actual "dialog_id" is stored in "shared"
  $app->routes->get('/log/:id/:connection_id/:dialog_id')->to(cb => \&_action_messages)
    ->name('share_dialog.messages');

  my $set = {
    cb         => \&_action_set,
    parameters => [{'$ref' => '#/parameters/connection_id'}, {'$ref' => '#/parameters/dialog_id'},],
    responses  => {
      302 => {description => '', schema => {}},
      200 => {
        description => '',
        schema      => {
          type       => 'object',
          required   => [qw(href id)],
          properties => {href => {type => 'string'}, id => {type => 'string'}}
        }
      }
    }
  };

  $app->extend_api_spec(
    '/connection/{connection_id}/dialog/{dialog_id}/share',
    delete => {%$set, operationId => 'removeSharedDialog'},
    get    => {%$set, operationId => 'shareDialogRedirect'},
    post   => {%$set, operationId => 'shareDialog'},
  );

  $app->extend_api_spec(
    '/connection/{connection_id}/dialog/{dialog_id}/share/status',
    get => {
      cb          => \&_action_status,
      operationId => 'shareDialogStatus',
      parameters =>
        [{'$ref' => '#/parameters/connection_id'}, {'$ref' => '#/parameters/dialog_id'}],
      responses => {
        200 => {
          description => '',
          schema      => {type => 'object', properties => {shared => {type => 'boolean'}}}
        }
      }
    },
  );
}

sub _action_messages {
  my $c      = shift;
  my $shared = $c->share_dialog->shared->{$c->stash('id')} or return $c->reply->not_found;
  my $dialog = $c->backend->dialog($shared);
  my %query;

  return $c->reply->not_found unless $dialog and $dialog->stash('share_dialog.id');

  $c->stash(page => 'convos-share-dialog');

  # TODO:
  $query{$_} = $c->param($_) for grep { defined $c->param($_) } qw(after before level limit match);
  $query{limit} ||= 60;
  $query{limit} = 200 if $query{limit} > 200;    # TODO: is this a good max?

  $c->delay(
    sub { $dialog->messages(\%query, shift->begin) },
    sub {
      my ($delay, $err, $messages) = @_;
      die $err if $err;
      my %res = (messages => $messages, end => @$messages < $query{limit} ? true : false);
      $c->respond_to(
        json => \%res,
        any  => sub { shift->render('plugin/share_dialog/messages', %res) }
      );
    },
  );
}

sub _action_set {
  my $c      = shift;
  my $method = $c->req->method;
  my $user   = $c->backend->user or return $c->unauthorized;
  my $dialog = $c->backend->dialog({})
    or return $c->render(json => E('Dialog not found.'), status => 404);
  my $id;

  if ($method eq 'GET' or $method eq 'POST') {
    $id = $dialog->stash->{'share_dialog.id'} ||= _id($dialog);
    $c->share_dialog->shared->{$id} = {
      connection_id => $c->stash('connection_id'),
      dialog_id     => $c->stash('dialog_id'),
      email         => $c->session('email'),
    };
  }
  elsif ($id = delete $dialog->stash->{'share_dialog.id'}) {
    delete $c->share_dialog->shared->{$id};
    $id = undef;
  }

  $c->delay(
    sub {
      my ($delay) = @_;
      $c->share_dialog->save($delay->begin);
      $dialog->connection->save($delay->begin);
    },
    sub {
      my ($delay, $err) = @_;
      my $href = $c->url_for('share_dialog.messages', {id => $id})->to_abs;
      die $err if $err;
      return $c->redirect_to($href) if $method eq 'GET';
      return $c->render(json => {}) if $method eq 'DELETE';
      return $c->render(json => {href => $href, id => $id});
    }
  );
}

sub _action_status {
  my $c      = shift;
  my $user   = $c->backend->user or return $c->unauthorized;
  my $dialog = $c->backend->dialog({})
    or return $c->render(json => E('Dialog not found.'), status => 404);

  $c->render(json => {shared => $dialog->stash('share_dialog.id') ? true : false});
}

sub _id { substr sha1_sum($^T . $_[0]->id . steady_time), 0, 10 }

sub TO_JSON { +{shared => shift->_shared} }

1;

=encoding utf8

=head1 NAME

Convos::Plugin::ShareDialog - Convos plugin to share dialog messages

=head1 DESCRIPTION

L<Convos::Plugin::ShareDialog> is loaded by default and adds sharing
functionality to Convos.

=head1 SYNOPSIS

You can enable this plugin by setting C<CONVOS_PLUGINS="SharePlugin">.

=head1 METHODS

=head2 register

See L<Convos::Plugin/register>.

=head1 SEE ALSO

L<Convos>

=cut

__DATA__
@@ plugin/share_dialog/messages.html.ep
% layout 'convos';
% title "$dialog_id - $connection_id";
<script>
document.addEventListener("beforeConvosStart", function(e) {
  e.detail.mixins = [Convos.mixin.messages];
  e.detail.data.dialog = new Convos.Dialog({
    connection_id: "<%= $connection_id %>",
    connection_name: "<%= (split '-', $connection_id)[1] %>",
    dialog_id: "<%= $dialog_id %>",
    user: new Convos.User({})
  });

% for my $msg (@$messages) {
  e.detail.data.dialog.addMessage(
    <%== Mojo::JSON::to_json($msg) %>,
    {disableNotifications: true}
  );
% }
});
</script>
<header>
  <div class="container">
    <h2>{{dialog.dialog_id}} - {{dialog.connection_name}}</h2>
    %= link_to 'index', 'v-tooltip.literal' => 'Chat', begin
      <i class="material-icons">chat</i>
    % end
    <a href="https://convos.by" v-tooltip.literal="About">
      %= image '/images/icon.svg', class => 'material-icons'
    </a>
  </div>
</header>
<main class="under-main-menu max-height">
  <div class="scroll-element">
    <div class="container" style="padding-bottom: 40px;">
      <component
        :is="'convos-message-' + msg.type"
        :dialog="dialog"
        :msg="msg"
        :user="dialog.user"
        v-if="msg.type"
        v-for="msg in dialog.messages">
        <div id="loader" class="centered">
          <div>
            <h4>Loading convos...</h4>
            <p class="error">This should not take too long.</p>
            <a href="">Reload <i class="material-icons">refresh</i></a>
          </div>
        </div>
      </component>
    </div>
  </div>
</main>
