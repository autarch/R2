package R2::Controller::Household;

use strict;
use warnings;

use R2::Schema::Household;
use R2::Util qw( string_is_empty );

use Moose;

BEGIN { extends 'R2::Controller::Base' }

with 'R2::Role::Controller::ContactPOST';


sub household : Chained('/account/_set_account') : PathPart('household') : Args(0) : ActionClass('+R2::Action::REST') { }

sub household_POST
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->account();

    unless ( $c->model('Authz')->user_can_add_contact( user    => $c->user(),
                                                       account => $account,
                                                     ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not allowed to add contacts',
              uri   => $account->uri(),
            );
    }

    my %p = $c->request()->household_params();
    $p{account_id} = $account->account_id();

    my @errors = R2::Schema::Household->ValidateForInsert(%p);

    my $household =
        $self->_insert_contact
            ( $c,
              'R2::Schema::Household',
              \%p,
              \@errors,
            );

    $c->redirect_and_detach( $household->uri() );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
