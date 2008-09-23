package R2::Controller::Contact;

use strict;
use warnings;

use base 'R2::Controller::Base';

use R2::Schema;
use R2::Schema::Address;
use R2::Schema::Contact;
use R2::Schema::File;
use R2::Schema::Person;
use R2::Schema::PhoneNumber;


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

    $c->stash()->{template} = '/person/new_person_form';
}

sub new_household_form : Local
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

    $c->stash()->{template} = '/household/new_household_form';
}

sub new_organization_form : Local
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

    $c->stash()->{template} = '/organization/new_organization_form';
}

sub _set_contact : Chained('/') : PathPart('contact') : CaptureArgs(1)
{
    my $self       = shift;
    my $c          = shift;
    my $contact_id = shift;

    my $contact = R2::Schema::Contact->new( contact_id => $contact_id );

    $c->redirect_and_detach('/')
        unless $contact;

    unless ( $c->model('Authz')->user_can_view_contact( user    => $c->user(),
                                                        contact => $contact,
                                                      ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not authorized to view this contact',
              uri   => $c->uri_for('/'),
            );
    }

    $c->stash()->{contact} = $contact;
}

sub contact : Chained('_set_contact') : PathPart('') : Args(0) : ActionClass('+R2::Action::REST') { }

sub contact_GET_html : Private
{
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    my $meth = '_display_' . lc $contact->contact_type();
    $self->$meth($c);
}

sub _display_person
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{person} = $c->stash()->{contact}->person();

    $c->stash()->{template} = '/person/view';
}

sub _display_household
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{household} = $c->stash()->{contact}->household();

    $c->stash()->{template} = '/household/view';
}

sub _display_organization
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{organization} = $c->stash()->{contact}->organization();

    $c->stash()->{template} = '/organization/view';
}

1;
