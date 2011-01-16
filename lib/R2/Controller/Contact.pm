package R2::Controller::Contact;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema;
use R2::Schema::Address;
use R2::Schema::Contact;
use R2::Schema::ContactNote;
use R2::Schema::File;
use R2::Schema::Person;
use R2::Schema::PhoneNumber;
use R2::Web::Tab;

use Moose;

BEGIN { extends 'R2::Controller::Base' }

with 'R2::Role::Controller::ContactCRUD';

sub new_person_form : Local {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'user_can_add_contact',
        { account => $c->account() },
        'You are not allowed to add contacts.',
        $c->account()->uri(),
    );

    $c->stash()->{template} = '/person/new_person_form';
}

sub new_household_form : Local {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'user_can_add_contact',
        { account => $c->account() },
        'You are not allowed to add contacts.',
        $c->account()->uri(),
    );

    $c->stash()->{template} = '/household/new_household_form';
}

sub new_organization_form : Local {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'user_can_add_contact',
        { account => $c->account() },
        'You are not allowed to add contacts.',
        $c->account()->uri(),
    );

    $c->stash()->{template} = '/organization/new_organization_form';
}

sub _set_contact : Chained('/account/_set_account') : PathPart('contact') : CaptureArgs(1) {
    my $self       = shift;
    my $c          = shift;
    my $contact_id = shift;

    my $contact = R2::Schema::Contact->new( contact_id => $contact_id );

    $c->redirect_and_detach( $c->domain()->application_uri( path => q{} ) )
        unless $contact;

    $self->_check_authz(
        $c,
        'user_can_view_contact',
        { contact => $contact },
        'You are not authorized to view this contact',
        $c->account()->uri(),
    );

    $c->stash()->{tabs} = $self->_contact_view_tabs($contact);

    $c->stash()->{contact} = $contact;

    $c->stash()->{real_contact} = $c->stash()->{contact}->real_contact();
}

sub _contact_view_tabs {
    my $self    = shift;
    my $contact = shift;

    return [
        map { R2::Web::Tab->new( %{$_} ) }{
            uri     => $contact->uri(),
            label   => 'basics',
            tooltip => 'Name, email, address, phone, etc.',
        }, {
            uri   => $contact->uri( view => 'donations' ),
            label => 'donations',
            tooltip => 'Donations from this ' . lc $contact->contact_type(),
        }, {
            uri     => $contact->uri( view => 'notes' ),
            label   => 'notes',
            tooltip => 'Notes of meetings, phone calls, etc.',
        }, {
            uri     => $contact->uri( view => 'emails' ),
            label   => 'emails',
            tooltip => 'Email to and from this '
                . lc $contact->contact_type(),
        }, {
            uri     => $contact->uri( view => 'history' ),
            label   => 'history',
            tooltip => 'Changes to this '
                . lc $contact->contact_type()
                . q{'s data},
        },
    ];
}

sub contact : Chained('_set_contact') : PathPart('') : Args(0) : ActionClass('+R2::Action::REST') {
}

sub contact_GET_html : Private {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $c->stash()->{tabs}[0]->set_is_selected(1);

    my $meth = '_display_' . lc $contact->contact_type();
    $self->$meth($c);
}

sub _display_person {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{person} = $c->stash()->{contact}->person();

    $c->stash()->{template} = '/person/view';
}

sub _display_household {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{household} = $c->stash()->{contact}->household();

    $c->stash()->{template} = '/household/view';
}

sub _display_organization {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{organization} = $c->stash()->{contact}->organization();

    $c->stash()->{template} = '/organization/view';
}

sub edit_form : Chained('_set_contact') : PathPart('edit_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $type = lc $c->stash->{contact}->contact_type();

    $c->stash()->{$type} = $c->stash()->{contact}->$type();

    $c->stash()->{template} = "/$type/edit_form";
}

sub contact_PUT : Private {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $self->_check_authz(
        $c,
        'user_can_edit_contact',
        { contact => $contact },
        'You are not allowed to edit contacts.',
        $c->account()->uri(),
    );

    $self->_update_contact(
        $c,
        $contact,
    );

    $c->redirect_and_detach( $contact->uri() );
}

sub donations : Chained('_set_contact') : PathPart('donations') : Args(0) : ActionClass('+R2::Action::REST') {
}

sub donations_GET_html : Private {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{tabs}[1]->set_is_selected(1);

    $c->stash()->{can_edit_donations}
        = $c->model('Authz')->user_can_edit_contact(
        user    => $c->user(),
        contact => $c->stash()->{contact},
        );

    $c->stash()->{template} = '/contact/donations';
}

sub new_donation_form : Chained('_set_contact') : PathPart('new_donation_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $self->_check_authz(
        $c,
        'user_can_edit_contact',
        { contact => $contact },
        'You are not allowed to add donations.',
        $contact->uri( view => 'donations' ),
    );

    $c->stash()->{template} = "/contact/new_donation_form";
}

sub donations_POST : Private {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $self->_check_authz(
        $c,
        'user_can_edit_contact',
        { contact => $contact },
        'You are not allowed to add donations.',
        $contact->uri( view => 'donations' ),
    );

    my %p = $c->request()->donation_params();

    eval { $contact->add_donation( %p, user => $c->user() ); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error => $e,
            uri   => $contact->uri( view => 'donations' ),
        );
    }

    $c->redirect_and_detach( $contact->uri( view => 'donations' ) );
}

sub _set_donation : Chained('_set_contact') : PathPart('donation') : CaptureArgs(1) {
    my $self        = shift;
    my $c           = shift;
    my $donation_id = shift;

    my $donation = R2::Schema::Donation->new( donation_id => $donation_id );

    $c->redirect_and_detach( $c->domain()->application_uri( path => q{} ) )
        unless $donation
            && $donation->contact_id()
            == $c->stash()->{contact}->contact_id();

    $c->stash()->{donation} = $donation;
}

sub donation_edit_form : Chained('_set_donation') : PathPart('edit_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $self->_check_authz(
        $c,
        'user_can_edit_contact',
        { contact => $contact },
        'You are not allowed to edit donations.',
        $contact->uri( view => 'donations' ),
    );

    $c->stash()->{template} = '/donation/edit_form';
}

sub donation : Chained('_set_donation') : PathPart('') : Args(0) : ActionClass('+R2::Action::REST') {
}

sub donation_GET_html {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $c->stash()->{tabs}[1]->set_is_selected(1);

    $c->stash()->{can_edit_donations}
        = $c->model('Authz')->user_can_edit_contact(
        user    => $c->user(),
        contact => $c->stash()->{contact},
        );

    $c->stash()->{template} = '/donation/view';
}

sub donation_PUT {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $self->_check_authz(
        $c,
        'user_can_edit_contact',
        { contact => $contact },
        'You are not allowed to edit donations.',
        $contact->uri( view => 'donations' ),
    );

    my %p = $c->request()->donation_params();

    my $donation = $c->stash()->{donation};

    eval { $donation->update( %p, user => $c->user() ); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error => $e,
            uri   => $donation->uri( view => 'edit_form' ),
        );
    }

    $c->redirect_and_detach( $contact->uri( view => 'donations' ) );
}

sub donation_DELETE {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $self->_check_authz(
        $c,
        'user_can_edit_contact',
        { contact => $contact },
        'You are not allowed to delete donations.',
        $contact->uri( view => 'donations' ),
    );

    my $donation = $c->stash()->{donation};

    eval { $donation->delete( user => $c->user() ); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error => $e,
            uri   => $contact->uri( view => 'donations' ),
        );
    }

    $c->redirect_and_detach( $contact->uri( view => 'donations' ) );
}

sub donation_confirm_deletion : Chained('_set_donation') : PathPart('confirm_deletion') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $self->_check_authz(
        $c,
        'user_can_edit_contact',
        { contact => $contact },
        'You are not allowed to delete donations.',
        $contact->uri( view => 'donations' ),
    );

    my $donation = $c->stash()->{donation};

    $c->stash()->{type} = 'donation';
    $c->stash()->{uri}  = $donation->uri();

    $c->stash()->{template} = '/shared/confirm_deletion';
}

sub _set_note : Chained('_set_contact') : PathPart('note') : CaptureArgs(1) {
    my $self            = shift;
    my $c               = shift;
    my $contact_note_id = shift;

    my $note
        = R2::Schema::ContactNote->new( contact_note_id => $contact_note_id );

    $c->redirect_and_detach( $c->domain()->application_uri( path => q{} ) )
        unless $note
            && $note->contact_id() == $c->stash()->{contact}->contact_id();

    $c->stash()->{note} = $note;
}

sub note_edit_form : Chained('_set_note') : PathPart('edit_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $self->_check_authz(
        $c,
        'user_can_edit_contact',
        { contact => $contact },
        'You are not allowed to edit notes.',
        $contact->uri( view => 'notes' ),
    );

    $c->stash()->{template} = '/note/edit_form';
}

sub notes : Chained('_set_contact') : PathPart('notes') : Args(0) : ActionClass('+R2::Action::REST') {
}

sub notes_GET_html : Private {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{tabs}[2]->set_is_selected(1);

    $c->stash()->{can_edit_notes} = $c->model('Authz')->user_can_edit_contact(
        user    => $c->user(),
        contact => $c->stash()->{contact},
    );

    $c->stash()->{template} = '/contact/notes';
}

sub notes_POST : Private {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $self->_check_authz(
        $c,
        'user_can_edit_contact',
        { contact => $contact },
        'You are not allowed to add notes.',
        $contact->uri( view => 'notes' ),
    );

    my %p = $c->request()->note_params();
    $p{datetime_format} = $c->request()->params()->{datetime_format};

    eval { $contact->add_note( %p, user_id => $c->user()->user_id(), ); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error => $e,
            uri   => $contact->uri( view => 'notes' ),
        );
    }

    $c->redirect_and_detach( $contact->uri( view => 'notes' ) );
}

sub note : Chained('_set_note') : PathPart('') : Args(0) : ActionClass('+R2::Action::REST') {
}

sub note_PUT {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $self->_check_authz(
        $c,
        'user_can_edit_contact',
        { contact => $contact },
        'You are not allowed to edit notes.',
        $contact->uri( view => 'notes' ),
    );

    my %p = $c->request()->note_params();
    $p{datetime_format} = $c->request()->params()->{datetime_format};

    my $note = $c->stash()->{note};

    eval { $note->update(%p); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error => $e,
            uri   => $note->uri( view => 'edit_form' ),
        );
    }

    $c->redirect_and_detach( $contact->uri( view => 'notes' ) );
}

sub note_DELETE {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $self->_check_authz(
        $c,
        'user_can_edit_contact',
        { contact => $contact },
        'You are not allowed to delete notes.',
        $contact->uri( view => 'notes' ),
    );

    my $note = $c->stash()->{note};

    eval { $note->delete(); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error => $e,
            uri   => $contact->uri( view => 'notes' ),
        );
    }

    $c->redirect_and_detach( $contact->uri( view => 'notes' ) );
}

sub note_confirm_deletion : Chained('_set_note') : PathPart('confirm_deletion') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $self->_check_authz(
        $c,
        'user_can_edit_contact',
        { contact => $contact },
        'You are not allowed to delete notes.',
        $contact->uri( view => 'notes' ),
    );

    my $note = $c->stash()->{note};

    $c->stash()->{type} = 'note';
    $c->stash()->{uri}  = $note->uri();

    $c->stash()->{template} = '/shared/confirm_deletion';
}

sub history : Chained('_set_contact') : PathPart('history') : Args(0) : ActionClass('+R2::Action::REST') {
}

sub history_GET_html : Private {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{tabs}[4]->set_is_selected(1);

    $c->stash()->{can_edit_contact}
        = $c->model('Authz')->user_can_edit_contact(
        user    => $c->user(),
        contact => $c->stash()->{contact},
        );

    $c->stash()->{template} = '/contact/history';
}

__PACKAGE__->meta()->make_immutable();

1;
