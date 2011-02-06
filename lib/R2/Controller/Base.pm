package R2::Controller::Base;

use strict;
use warnings;
use namespace::autoclean;

use R2::Config;
use R2::JSON;
use R2::Schema::File;
use R2::Web::CSS;
use R2::Web::Javascript;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

sub begin : Private {
    my $self = shift;
    my $c    = shift;

    R2::Schema->ClearObjectCaches();

    $self->_require_authen($c)
        if $self->_uri_requires_authen( $c->request()->uri() );

    return unless $c->request()->looks_like_browser();

    my $config = R2::Config->instance();

    unless ( $config->is_production() || $config->is_profiling() ) {
        $_->new()->create_single_file()
            for qw( R2::Web::CSS R2::Web::Javascript );
    }

    $self->_add_global_tabs($c);

    return 1;
}

sub _uri_requires_authen {
    my $self = shift;
    my $uri  = shift;

    return 0
        if $uri->path()
            =~ m{^/user/(?:login_form|forgot_password_form|authentication)};

    return 0 if $uri->path() =~ m{^/(?:die|robots\.txt|exit)};

    return 1;
}

sub _add_global_tabs {
    my $self = shift;
    my $c = shift;

    my $account = $c->account()
        or return;

    $c->tabs()->add_item($_)
        for (
        {
            uri     => $account->uri(),
            label   => 'Dashboard',
            tooltip => $account->name() . ' dashboard',
        }, {
            uri     => $account->uri( view => 'contacts' ),
            label   => 'Contacts',
            tooltip => 'Search and view contacts',
        }, {
            uri     => $account->uri( view => 'reports' ),
            label   => 'Reports',
            tooltip => 'Reports on your contacts and donations',
        },
        );

    return;
}

sub end : Private {
    my $self = shift;
    my $c    = shift;

    return $self->next::method($c)
        if $c->stash()->{rest};

    if (   ( !$c->response()->status() || $c->response()->status() == 200 )
        && !$c->response()->body()
        && !@{ $c->error() || [] } ) {
        $c->forward( $c->view() );
    }

    return;
}

sub _set_entity {
    my $self   = shift;
    my $c      = shift;
    my $entity = shift;

    $c->response()->body( R2::JSON->Encode($entity) );

    return 1;
}

sub _require_authen {
    my $self = shift;
    my $c    = shift;

    my $user = $c->user();

    return if $user;

    $c->redirect_and_detach('/user/login_form');
}

sub _check_authz {
    my $self         = shift;
    my $c            = shift;
    my $authz_method = shift;
    my $authz_params = shift;
    my $error        = shift;
    my $uri          = shift;

    return
        if $c->user()->$authz_method( %{$authz_params} );

    $c->redirect_with_error(
        error => $error,
        uri   => $uri,
    );
}

sub status_forbidden {
    my $self = shift;
    my $c = shift;

    $c->response->status(403);

    return;
}

__PACKAGE__->meta()->make_immutable();

1;
