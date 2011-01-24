package R2::Controller::Contact;

use strict;
use warnings;
use namespace::autoclean;

use Lingua::EN::Inflect qw( PL_N );
use R2::Schema;
use R2::Schema::Address;
use R2::Schema::Contact;
use R2::Schema::ContactNote;
use R2::Schema::File;
use R2::Schema::Person;
use R2::Schema::PhoneNumber;
use R2::Web::Tab;

use Moose;
use CatalystX::Routes;

BEGIN { extends 'R2::Controller::Base' }

with 'R2::Role::Controller::ContactCRUD';

for my $type (qw( person household organization )) {
    my $form     = 'new_' . $type . '_form';
    my $template = "$type/$form";

    get $form
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

        $c->stash()->{template} = $template;
    };
}

chain_point _set_contact
    => chained '/account/_set_account'
    => path_part 'contact'
    => capture_args 1
    => sub {
    my $self       = shift;
    my $c          = shift;
    my $contact_id = shift;

    my $contact = R2::Schema::Contact->new( contact_id => $contact_id );

    $c->redirect_and_detach( $c->domain()->application_uri( path => q{} ) )
        unless $contact;

    $self->_check_authz(
        $c,
        'can_view_contact',
        { contact => $contact },
        'You are not authorized to view this contact',
        $c->account()->uri(),
    );

    $self->_add_contact_view_tabs( $c, $contact );

    $c->stash()->{contact} = $contact;

    $c->stash()->{real_contact} = $c->stash()->{contact}->real_contact();
};

sub _add_contact_view_tabs {
    my $self    = shift;
    my $c       = shift;
    my $contact = shift;

    $c->add_tab($_)
        for (
        {
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
        }
        );
}

get_html q{}
    => chained '_set_contact'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $c->tab_by_id('basics')->set_is_selected(1);

    my $meth = '_display_' . lc $contact->contact_type();
    $self->$meth($c);
};

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

put q{}
    => chained '_set_contact'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    $self->_check_authz(
        $c,
        'can_edit_contact',
        { contact => $contact },
        'You are not authorized to edit this contact',
        $c->domain()->application_uri( path => q{} ),
    );

    $self->_update_contact(
        $c,
        $contact,
    );

    $c->redirect_and_detach( $contact->uri() );
};

get_html edit_form
    => chained '_set_contact'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash->{contact};

    $self->_check_authz(
        $c,
        'can_edit_contact',
        { contact => $contact },
        'You are not authorized to edit this contact',
        $c->domain()->application_uri( path => q{} ),
    );

    $c->tab_by_id('basics')->set_is_selected(1);

    my $type = lc $contact->contact_type();

    $c->stash()->{$type} = $contact->$type();

    $c->stash()->{template} = "/$type/edit_form";
};

for my $type ( qw( donation note ) ) {
    my $plural = PL_N($type);

    my $edit_perm = "can_edit_$plural";
    my $collection_template = "/contact/$plural";

    get_html $plural
        => chained '_set_contact'
        => args 0
        => sub {
            my $self = shift;
            my $c    = shift;

            $c->tab_by_id($plural)->set_is_selected(1);

            $c->stash()->{$edit_perm}
                = $c->user()->can_edit_contact( contact => $c->stash()->{contact} );

            $c->stash()->{template} = $collection_template;
        };

    my $new_form = "new_${type}_form";
    get_html $new_form
        => chained '_set_contact'
        => args 0
        => sub {
            my $self = shift;
            my $c    = shift;

            my $contact = $c->stash()->{contact};

            $self->_check_authz(
                $c,
                'can_edit_contact',
                { contact => $contact },
                "You are not allowed to add $plural.",
                $contact->uri( view => $plural ),
            );

            $c->tab_by_id($plural)->set_is_selected(1);

            $c->stash()->{template} = "/contact/$new_form";
        };

    my $params_method = "${type}_params";
    my $add_method = "add_$type";
    my $user_params_for_add
        = $type eq 'donation'
        ? sub { ( user    => $_[0]->user() ) }
        : sub { ( user_id => $_[0]->user()->user_id() ) };

    post $plural
        => chained '_set_contact'
        => args 0
        => sub {
            my $self = shift;
            my $c    = shift;

            my $contact = $c->stash()->{contact};

            $self->_check_authz(
                $c,
                'can_edit_contact',
                { contact => $contact },
                "You are not allowed to add $plural.",
                $contact->uri( view => $plural ),
            );

            my %p = $c->request()->$params_method();

            eval { $contact->$add_method( %p, $user_params_for_add->($c) ); };

            if ( my $e = $@ ) {
                $c->redirect_with_error(
                    error => $e,
                    uri   => $contact->uri( view => $new_form ),
                );
            }

            $c->redirect_and_detach( $contact->uri( view => $plural ) );
        };

    my $entity_chain_point = "_set_$type";
    my $class = 'R2::Schema::'
        . ( $type eq 'donation' ? 'Donation' : 'ContactNote' );
    my $id_col = $type eq 'donation' ? 'donation_id' : 'contact_note_id';

    chain_point $entity_chain_point
        => chained '_set_contact'
        => path_part $type
        => capture_args 1
        => sub {
            my $self = shift;
            my $c    = shift;
            my $id   = shift;

            my $entity = $class->new( $id_col => $id );

            $c->redirect_and_detach(
                $c->domain()->application_uri( path => q{} ) )
                unless $entity
                    && $entity->contact_id()
                    == $c->stash()->{contact}->contact_id();

            $c->stash()->{$type} = $entity;
        };

    my $edit_template = "/$type/edit_form";

    get_html edit_form
        => chained $entity_chain_point
        => args 0
        => sub {
            my $self = shift;
            my $c    = shift;

            my $contact = $c->stash()->{contact};

            $self->_check_authz(
                $c,
                'can_edit_contact',
                { contact => $contact },
                "You are not allowed to add $plural.",
                $contact->uri( view => $plural ),
            );

            $c->tab_by_id($plural)->set_is_selected(1);

            $c->stash()->{template} = $edit_template;
        };

    if ( $type eq 'donation' ) {
        my $view_template = "/$type/view";
        get_html q{}
            => chained $entity_chain_point
            => args 0
            => sub {
            my $self = shift;
            my $c    = shift;

            my $contact = $c->stash()->{contact};

            $c->stash()->{tabs}[1]->set_is_selected(1);

            $c->stash()->{$edit_perm} = $c->user()
                ->can_edit_contact( contact => $c->stash()->{contact} );

            $c->tab_by_id($plural)->set_is_selected(1);

            $c->stash()->{template} = $view_template;
        };
    }

    my $user_params_for_update
        = $type eq 'donation'
        ? sub { ( user    => $_[0]->user() ) }
        : sub { () };

    put q{}
        => chained $entity_chain_point
        => args 0
        => sub {
            my $self = shift;
            my $c    = shift;

            my $contact = $c->stash()->{contact};

            $self->_check_authz(
                $c,
                'can_edit_contact',
                { contact => $contact },
                "You are not allowed to add $plural.",
                $contact->uri( view => $plural ),
            );

            my %p = $c->request()->$params_method();

            my $entity = $c->stash()->{$type};

            eval { $entity->update( %p, $user_params_for_update->($c) ); };

            if ( my $e = $@ ) {
                $c->redirect_with_error(
                    error => $e,
                    uri   => $entity->uri( view => 'edit_form' ),
                );
            }

            $c->redirect_and_detach( $contact->uri( view => $plural ) );
        };

    del q{}
        => chained $entity_chain_point
        => args 0
        => sub {
            my $self = shift;
            my $c    = shift;

            my $contact = $c->stash()->{contact};

            $self->_check_authz(
                $c,
                'can_edit_contact',
                { contact => $contact },
                "You are not allowed to add $plural.",
                $contact->uri( view => $plural ),
            );

            my $entity = $c->stash()->{$type};

            eval { $entity->delete( user => $c->user() ); };

            if ( my $e = $@ ) {
                $c->redirect_with_error(
                    error => $e,
                    uri   => $contact->uri( view => $plural ),
                );
            }

            $c->redirect_and_detach( $contact->uri( view => $plural ) );
        };

    get_html confirm_deletion
        => chained $entity_chain_point
        => args 0
        => sub {
            my $self = shift;
            my $c    = shift;

            my $contact = $c->stash()->{contact};

            $self->_check_authz(
                $c,
                'can_edit_contact',
                { contact => $contact },
                "You are not allowed to add $plural.",
                $contact->uri( view => $plural ),
            );

            $c->tab_by_id($plural)->set_is_selected(1);

            my $entity = $c->stash()->{$type};

            $c->stash()->{type} = $type;
            $c->stash()->{uri}  = $entity->uri();

            $c->stash()->{template} = '/shared/confirm_deletion';
        };
}

get_html history
    => chained '_set_contact'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $c->tab_by_id('history')->set_is_selected(1);

    $c->stash()->{can_edit_contact}
        = $c->user()->can_edit_contact( contact => $c->stash()->{contact} );

    $c->stash()->{template} = '/contact/history';
};

__PACKAGE__->meta()->make_immutable();

1;
