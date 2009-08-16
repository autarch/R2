package R2::Controller::Household;

use strict;
use warnings;

use R2::Schema::Household;
use R2::Util qw( string_is_empty );

use Moose;

BEGIN { extends 'R2::Controller::Base' }

with 'R2::Role::Controller::ContactCRUD';


sub household : Chained('/account/_set_account') : PathPart('household') : Args(0) : ActionClass('+R2::Action::REST') { }

sub household_POST
{
    my $self = shift;
    my $c    = shift;

    $self->_check_authz( $c,
                         'user_can_add_contact',
                         { account => $c->account() },
                         'You are not allowed to add contacts.',
                         $c->account()->uri(),
                       );

    my $household =
        $self->_insert_contact
            ( $c,
              'R2::Schema::Household',
            );

    $c->redirect_and_detach( $household->uri() );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
