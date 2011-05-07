package R2::Controller::User;

use strict;
use warnings;
use namespace::autoclean;

use List::AllUtils qw( any );
use R2::Schema::User;
use R2::Util qw( string_is_empty );
use R2::Web::Form::Login;
use R2::Web::Form::User;

use Moose;
use CatalystX::Routes;

BEGIN { extends 'R2::Controller::Base' }

get_html login_form
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{return_to} 
        = $c->request()->params()->{return_to}
        || $c->session_object()->form_data()->{return_to}
        || $c->domain()->application_uri( path => q{} );

    $c->stash()->{template} = '/user/login_form';
};

get authentication
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my $method = $c->request()->param('x-tunneled-method');

    if ( $method && $method eq 'DELETE' ) {
        $self->_authentication_delete($c);
        return;
    }
    else {
        $c->redirect_and_detach(
            $c->domain()->application_uri( path => '/user/login_form' ) );
    }
};

post authentication
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my $result = $self->_process_form(
        $c,
        'Login',
        $c->domain()->application_uri( path => '/user/login_form' )
    );

    $self->_login_user( $c, $result->user(), $result->results_as_hash() );
};

del authentication
    => args 0
    => \&_authentication_delete;

sub _authentication_delete {
    my $self = shift;
    my $c    = shift;

    $c->unset_authen_cookie();

    $c->session_object()->add_message('You have been logged out.');

    my $redirect = $c->request()->parameters()->{return_to}
        || $c->domain()->application_uri( path => q{} );
    $c->redirect_and_detach($redirect);
};

sub _login_user {
    my $self    = shift;
    my $c       = shift;
    my $user    = shift;
    my $results = shift;

    my %expires = $results->{remember} ? ( expires => '+1y' ) : ();

    $c->set_authen_cookie(
        value => { user_id => $user->user_id() },
        %expires,
    );

    $c->session_object()
        ->add_message( 'Welcome to the site, ' . $user->first_name() );

    my $redirect_to = $results->{return_to}
        || $c->domain()->application_uri( path => q{} );

    $c->redirect_and_detach($redirect_to);
}

chain_point _set_user
    => chained '/'
    => path_part 'user'
    => capture_args 1 => sub {
    my $self    = shift;
    my $c       = shift;
    my $user_id = shift;

    my $user = R2::Schema::User->new( user_id => $user_id );

    $c->redirect_and_detach( $c->domain()->application_uri( path => q{} ) )
        unless $user;

    unless ( uc $c->request()->method() eq 'GET' ) {
        $self->_check_authz(
            $c,
            'can_edit_user',
            { user => $user },
            'You are not authorized to edit this user',
            $c->account()->uri(),
        );
    }

    $c->stash()->{user} = $user;
};

put q{}
    => chained '_set_user'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my $user = $c->stash()->{user};

    my $result;
    my $params;
    if ( exists $c->request()->params()->{is_disabled} ) {
        $params = { is_disabled => $c->request()->params()->{is_disabled} };
    }
    else {
        $result = $self->_process_form(
            $c,
            'User',
            $user->uri( view => 'edit_form' ),
            { entity => $user },
        );

        $params = $result->results_as_hash();
    }

    delete $params->{is_system_admin}
        if $c->user()->user_id() == $user->user_id();

    delete $params->{is_disabled}
        unless $c->user()->role()->name() eq 'Admin';

    delete $params->{role_id}
        unless $c->user()->can_edit_account( account => $c->account() );

    $user->update( %{$params}, user => $c->user() );

    my $whos
        = $c->user()->user_id() == $user->user_id()
        ? 'Your '
        : $user->display_name . q{'s};

    $c->session_object()->add_message( $whos . ' account has been updated' );

    $c->redirect_and_detach( $user->account()->uri( view => 'users' ) );
};

get_html edit_form
    => chained '_set_user'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'can_edit_user',
        { user => $c->stash()->{user} },
        'You are not authorized to edit this user',
        $c->account()->uri(),
    );

    $c->stash()->{template} = '/user/edit_form';
};

__PACKAGE__->meta()->make_immutable();

1;

