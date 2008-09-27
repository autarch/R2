package R2::Controller::Organization;

use strict;
use warnings;

use R2::Schema::Organization;
use R2::Util qw( string_is_empty );

use Moose;

BEGIN { extends 'R2::Controller::Base' }

with 'R2::Role::Controller::ContactPOST';


sub organization : Path('') : ActionClass('+R2::Action::REST') { }

sub organization_POST
{
    my $self = shift;
    my $c    = shift;

    unless ( $c->model('Authz')->user_can_add_contact( user    => $c->user(),
                                                       account => $c->user()->account(),
                                                     ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not allowed to add contacts',
              uri   => $c->uri_for('/'),
            );
    }

    my %p = $c->request()->organization_params();
    $p{account_id} = $c->user()->account_id();

    my @errors = R2::Schema::Organization->ValidateForInsert(%p);

    my $organization =
        $self->_insert_contact
            ( $c,
              'R2::Schema::Organization',
              \%p,
              \@errors,
            );

    $c->redirect_and_detach( $c->uri_for( '/contact/' . $organization->contact_id() ) );
}

1;
