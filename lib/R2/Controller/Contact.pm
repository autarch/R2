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
use R2::Web::Tab;


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

    $c->stash()->{tabs} = $self->_contact_view_tabs($contact);

    $c->stash()->{contact} = $contact;
}

sub _contact_view_tabs
{
    my $self    = shift;
    my $contact = shift;

    return [ map { R2::Web::Tab->new( %{ $_ } ) }
             { uri     => $contact->uri(),
               label   => 'basics',
               tooltip => 'Name, email, address, phone, etc.',
             },
             { uri     => $contact->uri( view => 'donations' ),
               label   => 'donations',
               tooltip => 'Donations from this contact',
             },
             { uri     => $contact->uri( view => 'interactions' ),
               label   => 'interactions',
               tooltip => 'Email, meetings, phone calls, etc.',
             },
             { uri     => $contact->uri( view => 'history' ),
               label   => 'history',
               tooltip => 'Changes to contact data made via this system',
             },
           ];
}

sub contact : Chained('_set_contact') : PathPart('') : Args(0) : ActionClass('+R2::Action::REST') { }

sub contact_GET_html : Private
{
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $c->stash()->{tabs}[0]->is_selected(1);

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

sub donations : Chained('_set_contact') : PathPart('donations') : Args(0) : ActionClass('+R2::Action::REST') { }

sub donations_GET_html : Private
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{real_contact} = $c->stash()->{contact}->real_contact();

    $c->stash()->{tabs}[0]->is_selected(1);

    $c->stash()->{template} = '/contact/donations';
}

sub donations_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my %p = $c->request()->donation_params();
    $p{date_format} = $c->request()->params()->{date_format};

    my $contact = $c->stash()->{contact};

    eval
    {
        $contact->add_donation(%p);
    };

    if ( my $e = $@ )
    {
        $c->_redirect_with_error
            ( error => $e,
              uri   => $contact->uri( view => 'donations' ),
            );
    }

    $c->redirect_and_detach( $contact->uri( view => 'donations' ) );
}

1;
