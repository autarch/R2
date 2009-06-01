package R2::Controller::Base;

use strict;
use warnings;

use R2::Config;
use R2::JSON;
use R2::Schema::File;
use R2::Web::CSS;
use R2::Web::Javascript;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }


sub begin : Private
{
    my $self = shift;
    my $c    = shift;

    R2::Schema->ClearObjectCaches();

    $self->_require_authen($c)
        if $self->_uri_requires_authen( $c->request()->uri() );

    return unless $c->request()->looks_like_browser();

    my $config = R2::Config->new();

    unless ( $config->is_production() || $config->is_profiling() )
    {
        $_->new()->create_single_file()
            for qw( R2::Web::CSS R2::Web::Javascript );
    }

    return 1;
}

sub _uri_requires_authen
{
    my $self = shift;
    my $uri  = shift;

    return 0
        if $uri->path() =~ m{^/user/(?:login_form|forgot_password_form|authentication)};

    return 0 if $uri->path() =~ m{^/(?:die|robots\.txt|exit)};

    return 1;
}

sub end : Private
{
    my $self = shift;
    my $c    = shift;

    return $self->next::method($c)
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

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
