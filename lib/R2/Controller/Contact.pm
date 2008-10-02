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

    my $account = $c->user()->account();

    unless ( $c->model('Authz')->user_can_add_contact( user    => $c->user(),
                                                       account => $account,
                                                     ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not allowed to add contacts',
              uri   => $account->dashboard_uri(),
            );
    }

    $c->stash()->{template} = '/person/new_person_form';
}

sub new_household_form : Local
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->user()->account();

    unless ( $c->model('Authz')->user_can_add_contact( user    => $c->user(),
                                                       account => $account,
                                                     ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not allowed to add contacts',
              uri   => $account->dashboard_uri(),
            );
    }

    $c->stash()->{template} = '/household/new_household_form';
}

sub new_organization_form : Local
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->user()->account();

    unless ( $c->model('Authz')->user_can_add_contact( user    => $c->user(),
                                                       account => $account,
                                                     ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not allowed to add contacts',
              uri   => $account->dashboard_uri(),
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
              uri   => $c->user()->account()->dashboard_uri(),
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

    $c->stash()->{tabs} = $self->_contact_view_tabs($c);

    my $meth = '_display_' . lc $contact->contact_type();
    $self->$meth($c);
}

sub _contact_view_tabs
{
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    return [ { uri      => $contact->uri(),
               text     => 'basics',
               selected => 1,
             },
             { uri      => $contact->uri( view => 'history' ),
               text     => 'history',
             },
             { uri      => $contact->uri( view => 'donations' ),
               text     => 'donations',
             },
           ];
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
