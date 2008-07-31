package R2::Controller::Base;

use strict;
use warnings;

use base 'Catalyst::Controller::REST';

use R2::Config;
use R2::JSON;
use R2::Web::CSS;
use R2::Web::Javascript;


sub begin : Private
{
    my $self = shift;
    my $c    = shift;

    R2::Schema->ClearObjectCaches();

    $self->_require_authen($c)
        if $self->_uri_requires_authen( $c->request()->uri() );

    return unless $c->request()->looks_like_browser();

    my $config = R2::Config->new();

    for my $class ( qw( R2::Web::CSS R2::Web::Javascript ) )
    {
        $class->new()->create_single_file()
            unless $config->is_production() || $config->is_profiling();
    }

    return 1;
}

sub _uri_requires_authen
{
    my $self = shift;
    my $uri  = shift;

    return 0
        if $uri->path() =~ m{^/user/(?:login_form|forgot_password_form|authentication)};

    return 1;
}

sub end : Private
{
    my $self = shift;
    my $c    = shift;

    return $self->NEXT::end($c)
        if $c->stash()->{rest};

    if ( ( ! $c->response()->status()
           || $c->response()->status() == 200 )
         && ! $c->response()->body()
         && ! @{ $c->error() || [] } )
    {
        $c->forward( $c->view() );
    }

    return;
}

sub _set_entity
{
    my $self   = shift;
    my $c      = shift;
    my $entity = shift;

    $c->response()->body( R2::JSON->Encode($entity) );

    return 1;
}

sub _require_authen
{
    my $self = shift;
    my $c    = shift;

    my $user = $c->user();

    return if $user;

    $c->redirect_and_detach( '/user/login_form' );
}

1;
