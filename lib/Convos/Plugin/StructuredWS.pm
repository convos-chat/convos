package Convos::Plugin::StructuredWS;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::Loader 'load_class';
use Mojo::Util 'camelize';
use Scalar::Util ();
use JSON::Validator;

use constant DEBUG => 1;

has namespaces => sub { [] };
has validator  => sub { JSON::Validator->new };

has _protocol => sub {
  return {
    type       => 'object',
    required   => [qw(data id method)],
    properties => {
      id     => {type => 'string', minLength => 1},
      method => {type => 'string', minLength => 4, regex => qr{.\#.}},
      data => {type => 'any'},
    }
  };
};

sub register {
  my ($self, $app, $config) = @_;

  $self->namespaces($config->{namespaces} || $app->routes->namespaces);
  $self->validator->coerce(1);
  $self->validator->schema($config->{spec});

  $app->helper('channels.dispatch' => sub { $self->_dispatch(@_) });

  if (my $r = $config->{route} // '/channel') {
    $r = $app->routes->websocket($r) unless ref $r;
    $r->to(cb => sub { shift->on(json => \&_on_json) });
  }
}

sub _dispatch {
  my ($self, $c, $req) = @_;
  my $v = $self->validator;
  my ($id, $schema, @err);

  # Detect invalid protocol structure
  @err = $v->validate($req, $self->_protocol);
  return {errors => \@err, id => $req->{id} || 0, status => 400} if @err;

  # Detect invalid request data
  $id     = $req->{id};
  $schema = $v->schema->get("/resources/$req->{method}");
  return _err($id, 'No such resource.', '/method', 400) unless defined $schema->{parameters};
  @err = _path($v->validate($req->{data}, $schema->{parameters}));
  return {errors => \@err, id => $req->{id}, status => 400} if @err;

  # Find controller and method
  my ($controller, $method) = split '#', $req->{method};
  my $class = $self->{loaded}{$controller} ||= $self->_load(camelize $controller);
  return _err($id, 'Unable to load controller.')    unless defined $class;
  return _err($id, 'Unable to find controller.')    unless $class;
  return _err($id, 'Unable to dispatch to method.') unless $class->can($method);

  # Dispatch to MyApp::Controller:: class and method
  # $new will not go out of scope, since it is closed over in the callback
  my $new = $class->new(%$c);
  Scalar::Util::weaken($new->{$_}) for qw(app tx);
  $new->$method(
    $req->{data},
    sub {
      my ($c, $res) = @_;
      $schema = $schema->{responses};
      $res->{id} = $id;
      $res->{status} ||= 200;
      my @err = $v->validate($res->{data},
        $schema->{$res->{status}}{schema} || $schema->{default}{schema});
      @$res{qw(errors status)} = ([_path(@err)], 500) if @err;
      $new->send({json => $res});
    }
  );

  return undef;
}

sub _err {
  return {
    errors => [{message => $_[1], path => $_[2] || '/method'}],
    id => $_[0],
    status => $_[3] || 500
  };
}

sub _load {
  my ($self, $class) = @_;

  for my $fqn (map {"${_}::$class"} @{$self->namespaces}) {
    warn "[Convos::Plugin::Channels] Loading $fqn...\n" if DEBUG;
    if (my $e = load_class $fqn) { ref $e ? die $e : return undef }
    if ($fqn->isa('Mojolicious::Controller')) { return $fqn }
  }

  return 0;
}

sub _on_json {
  my $c   = shift;
  my $res = $c->channels->dispatch(@_);
  $c->send({json => $res}) if $res;
}

sub _path {
  map { $_->{path} = "/data$_->{path}"; $_ } @_;
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::StructuredWS - Structured API over WebSockets

=head1 DESCRIPTION

L<Convos::Plugin::StructuredWS> is a plugin which allow you to communicate over
WebSockets with a structured format which is validated using
L<JSON::Validator>.

=head1 PROTOCOL

All messages are sent inside WebSocket frames as JSON messages.

=head2 Request

  {"data":{},"id":42,"method":"foo#bar"}

"id" need to be unique ID for this message. The "id" is echoed back when the
response is rendered, allowing the client to map the request to the response.

"method" is name of a controller and action, combined with a hash. The example
above will dispatch to the controller C<MyApp::Controller::User> and the method
C<bar()>.

The "data" field can be anything, but will always be validated using the JSON
schema.

=head2 Response

  {"data":{},"id":42,"status":200}

"id" is the same as the "id" from the request.

"status" defaults to "200" on valid response and "500" on invalid response.
Any other code can also be sent back to the client.

The "data" field can be anything, but will always be validated using the JSON
schema.

=head1 SYNOPSIS

  sub startup {
    my $app = shift;
    $self->plugin("Convos::Plugin::StructuredWS" => {spec => "/path/to/spec.json"});
  }

=head1 ATTRIBUTES

=head2 namespaces

  $namespaces = $self->namespaces;
  $self = $self->namespaces(["MyApp::Controller"]);

Defaults to L<Mojolicious::Routes/namespaces>.

=head2 validator

  $validator = $self->validator;
  $self = $self->validator(JSON::Validator->new);

Holds a L<JSON::Validator> object.

=head1 METHODS

=head2 register

  $self->register($app, \%config);

See L</SYNOPSIS>.

=head1 AUTHOR

Jan Henning Thorsen

=cut
