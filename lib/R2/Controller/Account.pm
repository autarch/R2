package R2::Controller::User;

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

1;
