package R2::Controller::Base;

use strict;
use warnings;
use namespace::autoclean;

use MooseX::Params::Validate qw( validated_list );
use R2::Config;
use R2::JSON;
use R2::Schema::File;
use R2::Types qw( Str Object );
use R2::Web::CSS;
use R2::Web::Javascript;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

sub begin : Private {
    my $self = shift;
    my $c    = shift;

    my $config = R2::Config->instance();

    unless ( $config->is_production() || $ENV{R2_ALLOW_REMOTE_REQUEST} ) {
        $self->_require_local_request($c);
    }

    # Catalyst used to set this directly, now it's only available via the PSGI
    # env.
    $ENV{SERVER_PORT} = $c->engine()->env()->{SERVER_PORT};

    R2::Schema->ClearObjectCaches();

    $self->_require_authen($c)
        if $self->_uri_requires_authen( $c->request()->uri() );

    return unless $c->request()->looks_like_browser();

    unless ( $config->is_production() || $config->is_profiling() ) {
        $_->new()->create_single_file()
            for qw( R2::Web::CSS R2::Web::Javascript );
    }

    $self->_add_global_tabs($c)
        if $self->_uri_requires_authen( $c->request()->uri() );

    return 1;
}

sub _require_local_request {
    my $self = shift;
    my $c    = shift;

    my $domain = $c->domain()->web_hostname();

    return if $c->req->hostname() =~ /^(?:localhost|\Q$domain\E)$/;

    warn
        "Request from non-local domain ($domain) is not allowed for dev server unless \$ENV{R2_ALLOW_REMOTE_REQUEST} is true\n";

    $self->status_forbidden($c);
    $c->response()->body('This request is not allowed.');

    $c->detach();
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
            uri     => $account->uri( view => 'tags' ),
            label   => 'Tags',
            tooltip => 'All tags for your contacts',
        }, {
            uri     => $account->uri( view => 'activities' ),
            label   => 'Activities',
            tooltip => 'All activities for your account',
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
        $c->response()->content_type('text/html; charset=utf-8');
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

sub _json_body {
    my $self = shift;
    my $c    = shift;

    return R2::JSON->Decode(
        do {
            local $/;
            my $body = $c->request()->body();
            <$body>;
        }
    );
}

sub _require_authen {
    my $self = shift;
    my $c    = shift;

    my $user = $c->user();

    return if $user;

    my $uri = $c->domain()->application_uri(
        path      => '/user/login_form',
        query     => { return_to => $c->request()->uri() },
        with_host => 1,
    );

    $c->redirect_and_detach($uri);
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

{
    my %spec = (
        location => { isa => Str | Object },
    );

    sub status_no_content {
        my $self = shift;
        my $c    = shift;
        my ($location) = validated_list( \@_, %spec );

        if ( $c->request()->looks_like_browser() ) {
            $c->response()->status(302);
            $c->response()->header( Location => $location );
        }
        else {
            $c->response()->status(204);
        }

        return;
    }
}

sub status_forbidden {
    my $self = shift;
    my $c    = shift;

    $c->response()->status(403);

    return;
}

sub _process_form {
    my $self   = shift;
    my $c      = shift;
    my $name   = shift;
    my $uri    = shift;
    my $form_p = shift;

    my $class = 'R2::Web::Form::' . $name;

    die "Bad form name ($name)" unless $class->can('new');

    my $form = $class->new(
        user => $c->user(),
        %{ $form_p || {} },
    );

    my $resultset = $form->process(
        params => {
            %{ $c->request()->params() },
            %{ $c->request()->uploads() },
        },
    );

    if ( !$resultset->is_valid() ) {
        $c->redirect_with_resultset(
            uri       => $uri,
            resultset => $resultset,
        );
    }

    return wantarray ? ( $form, $resultset ) : $resultset;
}

__PACKAGE__->meta()->make_immutable();

1;
