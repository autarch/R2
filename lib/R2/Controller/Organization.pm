package R2::Controller::Organization;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema::Organization;
use R2::Util qw( string_is_empty );

use Moose;

BEGIN { extends 'R2::Controller::Base' }

with 'R2::Role::Controller::ContactCRUD';

sub organization : Chained('/account/_set_account') : PathPart('organization')
    : Args(0) : ActionClass('+R2::Action::REST') {
}

sub organization_POST {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'user_can_add_contact',
        { account => $c->account() },
        'You are not allowed to add contacts.',
        $c->account()->uri(),
    );

    my $organization = $self->_insert_contact(
        $c,
        'R2::Schema::Organization',
    );

    $c->redirect_and_detach( $organization->uri() );
}

__PACKAGE__->meta()->make_immutable();

1;
