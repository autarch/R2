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
use R2::Search::Contact;
use R2::Util qw( string_is_empty );

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

        $c->tabs()->by_id('Contacts')->set_is_selected(1);

        $c->stash()->{template} = $template;
    };
}

get_html 'contacts'
    => chained '/account/_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{search} = R2::Search::Contact->new(
        account => $c->account(),
        limit   => 20,
        page    => 1,
    );

    $c->stash()->{template} = '/account/contacts';
};

get q{}
    => chained '/account/_set_account'
    => path_part 'contact'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my $params = $c->request()->params();
    my $name = $params->{ $params->{name_param} };

    my @contacts;
    if ( !string_is_empty($name) ) {
        my $contacts = R2::Search::Contact->new(
            account      => $c->account(),
            restrictions => 'Contact::ByName',
            name         => $name,
        )->contacts();

        while ( my $contact = $contacts->next() ) {
            push @contacts, $contact->real_contact()->serialize();
        }
    }

    return $self->status_ok(
        $c,
        entity => \@contacts,
    );
};

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

    $c->tabs()->by_id('Contacts')->set_is_selected(1)
        if $c->request()->looks_like_browser();

    $self->_add_contact_view_nav( $c, $contact );

    $c->stash()->{contact} = $contact;

    $c->stash()->{real_contact} = $c->stash()->{contact}->real_contact();
};

sub _add_contact_view_nav {
    my $self    = shift;
    my $c       = shift;
    my $contact = shift;

    $c->local_nav()->add_item($_)
        for (
        {
            uri     => $contact->uri(),
            id      => 'basics',
            label   => $contact->real_contact()->display_name(),
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

    $c->local_nav()->by_id('basics')->set_is_selected(1);

    $c->sidebar()->add_item('contact-search');
    $c->sidebar()->add_item('contact-tags');

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

    $c->local_nav()->by_id('basics')->set_is_selected(1);

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

            $c->local_nav()->by_id($plural)->set_is_selected(1);

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

            $c->local_nav()->by_id($plural)->set_is_selected(1);

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

            eval {
                R2::Schema->RunInTransaction(
                    sub {
                        if ( $type eq 'donation' ) {
                            $p{dedicated_to_contact_id}
                                = $self->_dedication_contact($c);

                            delete $p{dedication}
                                unless $p{dedicated_to_contact_id};
                        }

                        $contact->$add_method(
                            %p,
                            $user_params_for_add->($c),
                        );
                    }
                );
            };

            if ( my $e = $@ ) {
                $c->redirect_with_error(
                    error => $e,
                    uri   => $contact->uri( view => $new_form ),
                );
            }

            $c->redirect_and_detach( $contact->uri( view => $plural ) );
        };

    sub _dedication_contact {
        my $self   = shift;
        my $c = shift;

        my $params = $c->request()->params();

        return $params->{dedicated_to_contact_id}
            unless string_is_empty( $params->{dedicated_to_contact_id} );

        return if string_is_empty( $params->{dedicated_to} );

        my ( $first, $last ) = split /\s+/, $params->{dedicated_to}, 2;

        my $person = R2::Schema::Person->insert(
            first_name => $first,
            last_name  => $last,
            account_id => $c->account()->account_id(),
            user       => $c->user(),
        );

        return $person->contact_id();
    }

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

            $c->local_nav()->by_id($plural)->set_is_selected(1);

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

            $c->local_nav()->by_id($plural)->set_is_selected(1);

            $c->stash()->{$edit_perm} = $c->user()
                ->can_edit_contact( contact => $c->stash()->{contact} );

            $c->local_nav()->by_id($plural)->set_is_selected(1);

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

            $c->local_nav()->by_id($plural)->set_is_selected(1);

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

        $c->local_nav()->by_id('history')->set_is_selected(1);

        $c->stash()->{can_edit_contact} = $c->user()
            ->can_edit_contact( contact => $c->stash()->{contact} );

        $c->stash()->{template} = '/contact/history';
    };

post tags
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

        my @tags = map { s/^\s+|\s+$//; $_ } split /\s*,\s*/,
            ( $c->request()->params()->{tags} || q{} );

        $contact->add_tags( tags => \@tags ) if @tags;

        $self->_tags_as_entity_response( $c, 'created' );
    };

del tag
    => chained '_set_contact'
    => path_part 'tag',
    => args 1
    => sub {
        my $self   = shift;
        my $c      = shift;
        my $tag_id = shift;

        my $contact = $c->stash()->{contact};

        $self->_check_authz(
            $c,
            'can_edit_contact',
            { contact => $contact },
            'You are not authorized to edit this contact',
            $c->domain()->application_uri( path => q{} ),
        );

        my $contact_tag = R2::Schema::ContactTag->new(
            contact_id => $contact->contact_id(),
            tag_id     => $tag_id
        );

        $contact_tag->delete() if $contact_tag;

        $self->_tags_as_entity_response($c);
    };

sub _tags_as_entity_response {
    my $self   = shift;
    my $c      = shift;
    my $status = shift || 'ok';

    my $contact = $c->stash()->{contact};

    my @tags = map { $_->serialize() } $contact->tags()->all();
    $_->{'delete_uri'} = $contact->uri( view => 'tag/' . $_->{tag_id} )
        for @tags;

    my $meth = 'status_' . $status;

    my %p = (
        entity => {
            contact_id => $contact->contact_id(),
            tags       => \@tags,
        },
    );

    $p{location} = $contact->uri( view => 'tags' )
        if $status ne 'ok';

    $self->$meth( $c, %p );
}

__PACKAGE__->meta()->make_immutable();

1;
