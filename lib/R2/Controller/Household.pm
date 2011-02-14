package R2::Controller::Household;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema::Household;
use R2::Util qw( string_is_empty );

use Moose;
use CatalystX::Routes;

BEGIN { extends 'R2::Controller::Base' }

with 'R2::Role::Controller::ContactCRUD';

post households
    => chained '/account/_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'can_add_contact',
        { account => $c->account() },
        'You are not allowed to add contacts.',
        $c->account()->uri(),
    );

    my $household = $self->_insert_contact(
        $c,
        'R2::Schema::Household',
    );

    $c->redirect_and_detach( $household->uri() );
};

__PACKAGE__->meta()->make_immutable();

1;
