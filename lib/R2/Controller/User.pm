package R2::Controller::User;

use strict;
use warnings;
use namespace::autoclean;

use List::AllUtils qw( any );
use R2::Schema::User;
use R2::Util qw( string_is_empty );

use Moose;
use CatalystX::Routes;

BEGIN { extends 'R2::Controller::Base' }

get_html login_form
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{return_to} 
        = $c->request()->parameters->{return_to}
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

    my $username = $c->request()->param('username');
    my $pw       = $c->request()->param('password');

    my @errors;

    push @errors, {
        field   => 'password',
        message => 'You must provide a password.'
        }
        if string_is_empty($pw);

    my $user;
    unless (@errors) {
        $user = R2::Schema::User->new( username => $username );

        if ( $user->is_disabled() ) {
            push @errors, 'This account has been disabled.';
        }
        elsif ( !$user->check_password($pw) ) {
            push @errors,
                'The username or password you provided was not valid.';
        }
    }

    if (@errors) {
        $c->redirect_with_error(
            error => R2::Exception::DataValidation->new( errors => \@errors ),
            uri =>
                $c->domain()->application_uri( path => '/user/login_form' ),
            form_data => $c->request()->parameters(),
        );
    }

    $self->_login_user( $c, $user );
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
    my $self = shift;
    my $c    = shift;
    my $user = shift;

    my %expires
        = $c->request()->param('remember') ? ( expires => '+1y' ) : ();

    $c->set_authen_cookie(
        value => { user_id => $user->user_id() },
        %expires,
    );

    $c->session_object()
        ->add_message( 'Welcome to the site, ' . $user->first_name() );

    my $redirect_to = $c->request()->parameters()->{return_to}
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

    my %p = $c->request()->user_params();
    delete $p{is_system_admin}
        unless $c->user()->is_system_admin();
    delete $p{is_disabled}
        unless $c->user()->role()->name() eq 'Admin';

    delete @p{ 'password', 'password2' }
        unless any { !string_is_empty($_) } @p{ 'password', 'password2' };

    my @errors;

    my $password2 = $c->request()->params()->{password2};

    unless ( ( $p{password} // q{} ) eq ( $password2 // q{} ) ) {
        push @errors, 'The two passwords you provided did not match.';
    }

    my $user = $c->stash()->{user};

    unless (@errors) {
        eval { $user->update( %p, user => $c->user() ) };

        push @errors, $@
            if $@;
    }

    if (@errors) {
        my $e = R2::Exception::DataValidation->new( errors => \@errors );

        $c->redirect_with_error(
            error     => $e,
            uri       => $user->uri( view => 'edit_form' ),
            form_data => $c->request()->params(),
        );
    }

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

