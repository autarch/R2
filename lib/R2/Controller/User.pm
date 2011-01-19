package R2::Controller::User;

use strict;
use warnings;
use namespace::autoclean;

use LWPx::ParanoidAgent;
use R2::Schema::User;
use R2::Util qw( string_is_empty );

use Moose;

BEGIN { extends 'R2::Controller::Base' }

sub login_form : Local {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{return_to} 
        = $c->request()->parameters->{return_to}
        || $c->session_object()->form_data()->{return_to}
        || $c->domain()->application_uri( path => q{} );
}

sub authentication : Local : ActionClass('+R2::Action::REST') {
}

sub authentication_GET_html {
    my $self = shift;
    my $c    = shift;

    my $method = $c->request()->param('x-tunneled-method');

    if ( $method && $method eq 'DELETE' ) {
        $self->authentication_DELETE($c);
        return;
    }
    else {
        $c->redirect_and_detach(
            $c->domain()->application_uri( path => '/user/login_form' ) );
    }
}

sub authentication_POST {
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
        elsif ( ! $user->check_password($pw) ) {
            push @errors, 'The username or password you provided was not valid.';
        }
    }

    unless ($user) {
        $c->redirect_with_error(
            error => R2::Exception::DataValidation->new( errors => \@errors ),
            uri =>
                $c->domain()->application_uri( path => '/user/login_form' ),
            form_data => $c->request()->parameters(),
        );
    }

    $self->_login_user( $c, $user );
}

sub authentication_DELETE {
    my $self = shift;
    my $c    = shift;

    $c->unset_authen_cookie();

    $c->session_object()->add_message('You have been logged out.');

    my $redirect = $c->request()->parameters()->{return_to}
        || $c->domain()->application_uri( path => q{} );
    $c->redirect_and_detach($redirect);
}

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

sub edit_form : Local {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{return_to} 
        = $c->request()->parameters->{return_to}
        || $c->session_object()->form_data()->{return_to}
        || $c->domain()->application_uri( path => q{} );
}

__PACKAGE__->meta()->make_immutable();

1;

