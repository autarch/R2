package R2::Controller::Root;

use strict;
use warnings;
use namespace::autoclean;

use R2::Config;
use R2::Exceptions;

use Moose;
use CatalystX::Routes;

BEGIN { extends 'R2::Controller::Base' }

__PACKAGE__->config()->{namespace} = '';

get q{} => args 0 => sub {
    my $self = shift;
    my $c    = shift;

    $c->redirect_and_detach( $c->account()->uri() );
};

get 'exit' => args 0 => sub  {
    my $self = shift;
    my $c    = shift;

    R2::Exception->throw('Naughty attempt to kill R2')
        if R2::Config->instance()->is_production();

    exit 0;
};

get 'die' => args 0 => sub  {
    my $self = shift;
    my $c    = shift;

    R2::Exception->throw('Naughty attempt to kill R2')
        if R2::Config->instance()->is_production();

    die 'Dead';
};

get 'robots.txt' => args 0 => sub  {
    my $self = shift;
    my $c    = shift;

    $c->response()->content_type('text/plain');
    $c->response()->body("User-agent: *\nDisallow: /\n");
};

__PACKAGE__->meta()->make_immutable();

1;

__END__
