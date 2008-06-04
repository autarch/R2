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
              uri   => $c->uri_for( '/account', $account->account_id(), 'edit_form' ),
            );
    }

    $c->add_message( 'The ' . $account->name() . ' account has been updated' );

    $c->redirect_and_detach( $c->uri_for( '/account', $account->account_id() ) );
}

sub edit_form : Chained('_set_account') : PathPart('edit_form') : Args(0) { }

sub donation_settings : Chained('_set_account') : PathPart('donation_settings') : Args(0) { }

1;
