package R2::Controller::Organization;

use strict;
use warnings;

use R2::Schema::Organization;
use R2::Util qw( string_is_empty );

use Moose;

BEGIN { extends 'R2::Controller::Base' }

with 'R2::Role::Controller::ContactPOST';


sub organization : Chained('/account/_set_account') : PathPart('organization') : Args(0) : ActionClass('+R2::Action::REST') { }

sub organization_POST
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->account();

    $self->_check_authz( $c,
                         'user_can_edit_contact',
                         { account => $account },
                         'You are not allowed to add contacts',
                         $account->uri(),
                       );

    my %p = $c->request()->organization_params();
    $p{account_id} = $account->account_id();

    my @errors = R2::Schema::Organization->ValidateForInsert(%p);

    my $organization =
        $self->_insert_contact
            ( $c,
              'R2::Schema::Organization',
              \%p,
              \@errors,
            );

    $c->redirect_and_detach( $organization->uri() );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
