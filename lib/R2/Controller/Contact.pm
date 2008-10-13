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

    $c->stash()->{template} = '/person/new_person_form';
}

sub new_household_form : Local
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

    $c->stash()->{template} = '/household/new_household_form';
}

sub new_organization_form : Local
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

    $c->stash()->{template} = '/organization/new_organization_form';
}

sub _set_contact : Chained('/account/_set_account') : PathPart('contact') : CaptureArgs(1)
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
              uri   => $c->account()->uri(),
            );
    }

    $c->stash()->{tabs} = $self->_contact_view_tabs($contact);

    $c->stash()->{contact} = $contact;

    $c->stash()->{real_contact} = $c->stash()->{contact}->real_contact();
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

    $c->stash()->{tabs}[1]->is_selected(1);

    $c->stash()->{can_edit_donations} =
        $c->model('Authz')->user_can_edit_contact( user    => $c->user(),
                                                   contact => $c->stash()->{contact},
                                                 );

    $c->stash()->{template} = '/contact/donations';
}

sub donations_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->account();
    my $contact = $c->stash()->{contact};

    unless ( $c->model('Authz')->user_can_edit_contact( user    => $c->user(),
                                                        contact => $c->stash()->{contact},
                                                      ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not allowed to add donations',
              uri   => $contact->uri( view => 'donations' ),
            );
    }

    my %p = $c->request()->donation_params();
    $p{date_format} = $c->request()->params()->{date_format};

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

sub _set_donation : Chained('_set_contact') : PathPart('donation') : CaptureArgs(1)
{
    my $self        = shift;
    my $c           = shift;
    my $donation_id = shift;

    my $donation = R2::Schema::Donation->new( donation_id => $donation_id );

    $c->redirect_and_detach('/')
        unless $donation && $donation->contact_id() == $c->stash()->{contact}->contact_id();

    $c->stash()->{donation} = $donation;
}

sub donation_edit_form : Chained('_set_donation') : PathPart('edit_form') : Args(0)
{
    my $self        = shift;
    my $c           = shift;

    my $account = $c->account();
    my $contact = $c->stash()->{contact};

    unless ( $c->model('Authz')->user_can_edit_contact( user    => $c->user(),
                                                        contact => $c->stash()->{contact},
                                                      ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not allowed to edit donations',
              uri   => $contact->uri( view => 'donations' ),
            );
    }

    $c->stash()->{template} = '/donation/edit_form';
}

sub donation : Chained('_set_donation') : PathPart('') : Args(0) : ActionClass('+R2::Action::REST') { }

sub donation_PUT
{
    my $self        = shift;
    my $c           = shift;

    my $account = $c->account();
    my $contact = $c->stash()->{contact};

    unless ( $c->model('Authz')->user_can_edit_contact( user    => $c->user(),
                                                        contact => $c->stash()->{contact},
                                                      ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not allowed to edit donations',
              uri   => $contact->uri( view => 'donations' ),
            );
    }

    my %p = $c->request()->donation_params();
    $p{date_format} = $c->request()->params()->{date_format};

    my $donation = $c->stash()->{donation};

    eval
    {
        $donation->update(%p);
    };

    if ( my $e = $@ )
    {
        $c->_redirect_with_error
            ( error => $e,
              uri   => $donation->uri( view => 'edit_form' ),
            );
    }

    $c->redirect_and_detach( $contact->uri( view => 'donations' ) );
}

sub donation_DELETE
{
    my $self        = shift;
    my $c           = shift;

    my $account = $c->account();
    my $contact = $c->stash()->{contact};

    unless ( $c->model('Authz')->user_can_edit_contact( user    => $c->user(),
                                                        contact => $c->stash()->{contact},
                                                      ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not allowed to delete donations',
              uri   => $contact->uri( view => 'donations' ),
            );
    }

    my $donation = $c->stash()->{donation};

    eval
    {
        $donation->delete();
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

sub donation_confirm_deletion : Chained('_set_donation') : PathPart('confirm_deletion') : Args(0)
{
    my $self        = shift;
    my $c           = shift;

    my $account = $c->account();
    my $contact = $c->stash()->{contact};

    unless ( $c->model('Authz')->user_can_edit_contact( user    => $c->user(),
                                                        contact => $c->stash()->{contact},
                                                      ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not allowed to delete donations',
              uri   => $contact->uri( view => 'donations' ),
            );
    }

    my $donation = $c->stash()->{donation};

    $c->stash()->{type} = 'donation';
    $c->stash()->{uri} = $donation->uri();

    $c->stash()->{template} = '/shared/confirm_deletion';
}

sub interactions : Chained('_set_contact') : PathPart('interactions') : Args(0) : ActionClass('+R2::Action::REST') { }

sub interactions_GET_html : Private
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{tabs}[2]->is_selected(1);

    $c->stash()->{can_edit_interactions} =
        $c->model('Authz')->user_can_edit_contact( user    => $c->user(),
                                                   contact => $c->stash()->{contact},
                                                 );

    $c->stash()->{template} = '/contact/interactions';
}

sub interactions_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->account();
    my $contact = $c->stash()->{contact};

    unless ( $c->model('Authz')->user_can_edit_contact( user    => $c->user(),
                                                        contact => $c->stash()->{contact},
                                                      ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not allowed to add interactions',
              uri   => $contact->uri( view => 'interactions' ),
            );
    }

    my %p = $c->request()->interaction_params();
    $p{date_format} = $c->request()->params()->{date_format};

    eval
    {
        $contact->add_interaction(%p);
    };

    if ( my $e = $@ )
    {
        $c->_redirect_with_error
            ( error => $e,
              uri   => $contact->uri( view => 'interactions' ),
            );
    }

    $c->redirect_and_detach( $contact->uri( view => 'interactions' ) );
}

1;
