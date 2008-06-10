package R2::Controller::Account;

use strict;
use warnings;

use base 'R2::Controller::Base';


sub _set_account : Chained('/') : PathPart('account') : CaptureArgs(1)
{
    my $self       = shift;
    my $c          = shift;
    my $account_id = shift;

    my $account = R2::Schema::Account->new( account_id => $account_id );

    $c->redirect_and_detach('/')
        unless $account;

    unless ( $c->model('Authz')->user_can_view_account( user    => $c->user(),
                                                        account => $account,
                                                      ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not authorized to view this account',
              uri   => $c->uri_for('/'),
            );
    }

    $c->stash()->{account} = $account;
}

sub account : Chained('_set_account') : PathPart('') : Args(0) : ActionClass('+R2::Action::REST') { }

sub account_GET_html : Private
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/account/view';
}

sub account_PUT : Private
{
    my $self = shift;
    my $c    = shift;

    my %p = $c->request()->account_params();
    delete $p{domain_id}
        unless $c->user()->is_system_admin();

    my $account = $c->stash()->{account};

    eval { $account->update(%p) };

    if ( my $e = $@ )
    {
        $c->_redirect_with_error
            ( error => $e,
              uri   => $c->uri_for( $account->account_id(), 'edit_form' ),
            );
    }

    $c->add_message( 'The ' . $account->name() . ' account has been updated' );

    $c->redirect_and_detach( $c->uri_for( $account->account_id() ) );
}

sub edit_form : Chained('_set_account') : PathPart('edit_form') : Args(0) { }

sub donation_settings : Chained('_set_account') : PathPart('donation_settings') : Args(0) { }

sub donation_sources_form : Chained('_set_account') : PathPart('donation_sources_form') : Args(0) { }

sub donation_source : Chained('_set_account') : PathPart('donation_source') : Args(0) : ActionClass('+R2::Action::REST') { }

sub donation_source_GET_html : Private { }

sub donation_source_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my @sources = $c->request()->donation_source_names();

    unless (@sources)
    {
        $c->_redirect_with_error
            ( error => 'You must have at least one donation source.',
              uri   => $c->uri_for( $account->account_id(), 'donation_source' ),
            );
    }

    eval
    {
        $account->replace_donation_sources(@sources);
    };

    if ( my $e = $@ )
    {
        $c->_redirect_with_error
            ( error => $e,
              uri   => $c->uri_for( $account->account_id(), 'donation_source' ),
            );
    }

    $c->add_message( 'The donation sources for ' . $account->name() . ' have been updated' );

    $c->redirect_and_detach( $c->uri_for( $account->account_id(), 'donation_settings' ) );
}

sub donation_targets_form : Chained('_set_account') : PathPart('donation_targets_form') : Args(0) { }

sub donation_target : Chained('_set_account') : PathPart('donation_target') : Args(0) : ActionClass('+R2::Action::REST') { }

sub donation_target_GET_html : Private { }

sub donation_target_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my @targets = $c->request()->donation_target_names();

    unless (@targets)
    {
        $c->_redirect_with_error
            ( error => 'You must have at least one donation target.',
              uri   => $c->uri_for( $account->account_id(), 'donation_target' ),
            );
    }

    eval
    {
        $account->replace_donation_targets(@targets);
    };

    if ( my $e = $@ )
    {
        $c->_redirect_with_error
            ( error => $e,
              uri   => $c->uri_for( $account->account_id(), 'donation_target' ),
            );
    }

    $c->add_message( 'The donation targets for ' . $account->name() . ' have been updated' );

    $c->redirect_and_detach( $c->uri_for( $account->account_id(), 'donation_settings' ) );
}

sub payment_types_form : Chained('_set_account') : PathPart('payment_types_form') : Args(0) { }

sub payment_type : Chained('_set_account') : PathPart('payment_type') : Args(0) : ActionClass('+R2::Action::REST') { }

sub payment_type_GET_html : Private { }

sub payment_type_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my @types = $c->request()->payment_type_names();

    unless (@types)
    {
        $c->_redirect_with_error
            ( error => 'You must have at least one payment source.',
              uri   => $c->uri_for( $account->account_id(), 'payment_type' ),
            );
    }

    eval
    {
        $account->replace_payment_types(@types);
    };

    if ( my $e = $@ )
    {
        $c->_redirect_with_error
            ( error => $e,
              uri   => $c->uri_for( $account->account_id(), 'payment_type' ),
            );
    }

    $c->add_message( 'The payment types for ' . $account->name() . ' have been updated' );

    $c->redirect_and_detach( $c->uri_for( $account->account_id(), 'donation_settings' ) );
}



1;
