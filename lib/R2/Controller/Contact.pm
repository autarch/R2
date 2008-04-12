package R2::Controller::Contact;

use strict;
use warnings;

use base 'R2::Controller::Base';

use R2::Schema;
use R2::Schema::Person;


sub new_person_form : Local
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

    $c->stash()->{template} = '/contact/new-person-form';
}

sub new_contact : Path('/contact') : ActionClass('+R2::Action::REST') { }

sub new_contact_POST
{
    my $self = shift;
    my $c    = shift;

    my %p = $c->request()->person_params();

    my $person;
    my $insert_sub =
        sub
        {
            $person = R2::Schema::Person->insert(%p);
        };

    eval { R2::Schema->RunInTransaction($insert_sub) };

    if ( my $e = $@ )
    {
        $c->_redirect_with_error( error  => $e,
                                  uri    => '/contact/new_person_form',
                                  params => $c->request()->params(),
                                );
    }

    $c->redirect_and_detach( $c->uri_for( '/contact/' . $person->contact_id() ) );
}


1;
