package R2::Controller::Contact;

use strict;
use warnings;
use namespace::autoclean;

use Lingua::EN::Inflect qw( PL_N );
use R2::Schema;
use R2::Schema::Address;
use R2::Schema::Contact;
use R2::Schema::ContactNote;
use R2::Schema::EmailAddress;
use R2::Schema::File;
use R2::Schema::Person;
use R2::Schema::PhoneNumber;
use R2::Search::Contact;
use R2::Search::Household;
use R2::Search::Organization;
use R2::Search::Person;
use R2::Web::Form::ContactNote;
use R2::Web::Form::Donation;
use R2::Util qw( string_is_empty studly_to_calm );
use Scalar::Util qw( blessed );

use Moose;
use CatalystX::Routes;

BEGIN { extends 'R2::Controller::Base' }

for my $type (qw( contact person household organization )) {

    if ( $type ne 'contact' ) {
        my $form     = 'new_' . $type . '_form';
        my $template = "$type/$form";

        get_html $form
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

    my $pl_type = PL_N($type);

    my $search_class = 'R2::Search::' . ucfirst $type;
    my $schema_class = 'R2::Schema::' . ucfirst $type;

    get_html $pl_type
        => chained '/account/_set_account'
        => args 0
        => sub {
            my $self = shift;
            my $c    = shift;

            $self->_contact_search( $c, undef, $search_class );
        };

    get $pl_type
        => chained '/account/_set_account'
        => args 0
        => sub {
            my $self = shift;
            my $c    = shift;

            my $name = $c->request()->parameters()
                ->{ $c->request()->parameters()->{name_param} };

            my @contacts;
            if ( !string_is_empty($name) ) {
                my $contacts = $search_class->new(
                    account      => $c->account(),
                    restrictions => 'Contact::ByName',
                    name         => $name,
                )->contacts();

                while ( my $contact = $contacts->next() ) {
                    push @contacts, $contact->serialize();
                }
            }

            return $self->status_ok(
                $c,
                entity => \@contacts,
            );
        };

    post $pl_type
        => chained '/account/_set_account'
        => args 0
        => sub {
            my $self = shift;
            my $c    = shift;

            $self->_check_authz(
                $c,
                'can_add_contact',
                { account => $c->account() },
                "You are not allowed to add $pl_type.",
                $c->account()->uri(),
            );

            my $contact = $self->_insert_contact(
                $c,
                $schema_class
            );

            my $name = $contact->real_contact()->display_name();

            $c->session_object()
                ->add_message("A contact record for $name has been added.");

            $c->redirect_and_detach( $contact->uri() );
        };

    get_html $type . '_search'
        => path_part $pl_type
        => chained '/account/_set_account'
        => args 1
        => sub {
            my $self = shift;
            my $c    = shift;
            my $path = shift;

            $self->_contact_search( $c, $path, $search_class );
        };
}

sub _contact_search {
    my $self         = shift;
    my $c            = shift;
    my $path         = shift;
    my $search_class = shift;

    $c->tabs()->by_id('Contacts')->set_is_selected(1);

    my %p;
    if ( defined $path ) {
        for my $pair ( split /;/, $path ) {
            my ( $k, $v ) = split /=/, $pair;

            push @{ $p{$k} }, $v;
        }
    }

    my @restrictions;
    push @restrictions, 'Contact::ByName'
        if $p{name};
    push @restrictions, 'Contact::ByTag'
        if $p{tag};

    $p{restrictions} = \@restrictions;

    my $params = $c->request()->params();
    for my $key ( qw( page limit order_by reverse_order ) ) {
        $p{$key} = $params->{$key}
            if exists $params->{$key};
    }

    $p{limit} //= 50;

    my $search = $search_class->new(
        account => $c->account(),
        %p,
    );

    if ( $search->count() == 1 ) {
        $c->redirect_and_detach(
            $search->contacts()->next()->uri( with_host => 1 ) );
    }

    $c->user()->save_most_recent_search( search => $search );

    $c->stash()->{search} = $search;

    $c->stash()->{template} = '/account/contacts';
}

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
        unless $contact
            && $contact->account_id() == $c->stash()->{account}->account_id();

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

    my $name = $contact->real_contact()->display_name();

    $c->session_object()
        ->add_message("The contact record for $name has been updated.");

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

get_html confirm_deletion
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
        'You are not allowed to delete contacts.',
        $contact->uri(),
    );

    $c->stash()->{type} = 'contact';
    $c->stash()->{uri}  = $contact->uri();

    $c->stash()->{template} = '/shared/confirm_deletion';
};

del q{}
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
        'You are not allowed to delete contacts.',
        $contact->uri(),
    );

    my $name = $contact->real_contact()->display_name();

    eval { $contact->delete( user => $c->user() ); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error => $e,
            uri   => $contact->uri(),
        );
    }

    $c->session_object()
        ->add_message("The contact record for $name has been deleted.");

    $c->redirect_and_detach( $c->stash()->{account}->uri() );
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

    my $form_class = $type eq 'donation' ? 'Donation' : 'ContactNote';
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

            my $result = $self->_process_form(
                $c,
                $form_class,
                $contact->uri( view => $new_form )
            );

            eval {
                R2::Schema->RunInTransaction(
                    sub {
                        my $p = $result->results_as_hash();

                        if ( $type eq 'donation' ) {
                            $self->_dedication_contact( $c, $result, $p );
                        }

                        $contact->$add_method(
                            %{$p},
                            $user_params_for_add->($c),
                        );
                    }
                );
            };

            if ( my $e = $@ ) {
                $c->redirect_with_error(
                    error     => $e,
                    uri       => $contact->uri( view => $new_form ),
                    form_data => $result->results_as_hash()
                );
            }

            my $name = $contact->real_contact()->display_name();

            $c->session_object()
                ->add_message("A new $type for $name has been added.");

            $c->redirect_and_detach( $contact->uri( view => $plural ) );
        };

    sub _dedication_contact {
        my $self   = shift;
        my $c      = shift;
        my $result = shift;
        my $p      = shift;

        if ( $p->{dedicated_to_contact_id} ) {
            delete $p->{dedicated_to};
            return;
        }

        if (   string_is_empty( $p->{dedicated_to_contact_id} )
            && string_is_empty( $p->{dedicated_to} ) ) {

            delete $p->{dedication};
            return;
        }

        my ( $first, $last ) = split /\s+/, delete $p->{dedicated_to}, 2;

        my $person = R2::Schema::Person->insert(
            first_name => $first,
            last_name  => $last,
            account_id => $c->account()->account_id(),
            user       => $c->user(),
        );

        $p->{dedicated_to_contact_id} = $person->contact_id();

        return;
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

            my $result = $self->_process_form(
                $c,
                $form_class,
                $contact->uri( view => $new_form )
            );

            my $entity = $c->stash()->{$type};

            eval {
                R2::Schema->RunInTransaction(
                    sub {
                        my $p = $result->results_as_hash();

                        if ( $type eq 'donation' ) {
                            $self->_dedication_contact( $c, $result, $p );
                        }

                        $entity->update(
                            %{$p},
                            $user_params_for_update->($c),
                        );
                    }
                );
            };

            if ( my $e = $@ ) {
                $c->redirect_with_error(
                    error     => $e,
                    uri       => $entity->uri( view => 'edit_form' ),
                    form_data => $result->results_as_hash()
                );
            }

            $c->session_object()
                ->add_message("The $type has been updated.");

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

            $c->session_object()
                ->add_message("The $type was deleted.");

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

sub _contact_params_for_class {
    my $self  = shift;
    my $c     = shift;
    my $class = shift;

    my ($type) = $class =~ /^R2::Schema::(\w+)/;

    my $params_method = lc $type . '_params';

    my %p = $c->request()->$params_method();
    $p{account_id} = $c->account()->account_id();

    unless ( $c->user()->is_system_admin() ) {
        delete $p{email_opt_out};
    }

    return \%p;
}

sub _contact_image {
    my $self   = shift;
    my $c      = shift;
    my $errors = shift;

    my $image = $c->request()->upload('image');

    if ( $image && !R2::Schema::File->TypeIsImage( $image->type() ) ) {
        push @{$errors}, {
            field   => 'image',
            message => 'The image you provided is not a GIF, JPG, or PNG.',
            };
    }

    return $image;
}

for my $class_suffix (qw( EmailAddress Website MessagingProvider Address PhoneNumber )) {
    my $type  = studly_to_calm($class_suffix);
    my $class = 'R2::Schema::' . $class_suffix;

    my $new_param_set_meth = 'new_' . $type . '_param_sets';

    my $new_sub = sub {
        my $self   = shift;
        my $c      = shift;
        my $errors = shift;

        my $sets = $c->request()->$new_param_set_meth();

        for my $suffix ( keys %{$sets} ) {
            my @e = $class->ValidateForInsert(
                %{ $sets->{$suffix} },
                contact_id => 1,
            );

            $self->_apply_suffix_to_fields_in_errors( $suffix, \@e );

            push @{$errors}, @e;
        }

        return [ values %{$sets} ];
    };

    my $plural = $type . ( $type =~ /s$/ ? 'es' : 's' );
    my $new_meth = '_new_' . $plural;

    __PACKAGE__->meta()->add_method( $new_meth => $new_sub );

    my $updated_param_set_meth = 'updated_' . $type . '_param_sets';

    my $pk_col = $class->Table()->primary_key()->[0]->name();

    my $updated_sub = sub {
        my $self   = shift;
        my $c      = shift;
        my $errors = shift;

        my $sets = $c->request()->$updated_param_set_meth();

        for my $id ( keys %{$sets} ) {
            my $object = $class->new( $pk_col => $id ) or next;

            my @e = $object->validate_for_update( %{ $sets->{$id} } );

            $self->_apply_suffix_to_fields_in_errors( $id, \@e );

            push @{$errors}, @e;
        }

        return $sets;
    };

    my $updated_meth = '_updated_' . $plural;

    __PACKAGE__->meta()->add_method( $updated_meth => $updated_sub );
}

sub _custom_fields {
    my $self   = shift;
    my $c      = shift;
    my $errors = shift;

    my %values = $c->request()->custom_field_values();

    my @fields;
    for my $id ( keys %values ) {
        my $field = R2::Schema::CustomField->new( custom_field_id => $id );

        $values{$id} = $field->clean_value( $values{$id} );

        if ( my @e = $field->validate_value( $values{$id} ) ) {
            push @{$errors}, @e;
            next;
        }

        if ( $field->is_required() && string_is_empty( $values{$id} ) ) {
            push @{$errors}, {
                message => 'The ' . $field->label() . ' field is required.',
                field   => 'custom_field_' . $field->custom_field_id(),
                };

            next;
        }

        next if string_is_empty( $values{$id} );

        push @fields, [ $field, $values{$id} ];
    }

    return \@fields;
}

sub _apply_suffix_to_fields_in_errors {
    my $self   = shift;
    my $suffix = shift;
    my $errors = shift;

    for my $e ( @{$errors} ) {
        if ( ref $e && $e->{field} ) {
            $e->{field} .= q{-} . $suffix;
        }
    }
}

sub _insert_contact {
    my $self  = shift;
    my $c     = shift;
    my $class = shift;

    my $contact_p = $self->_contact_params_for_class( $c, $class );

    my @errors = $class->ValidateForInsert( %{$contact_p} );

    my $image = $self->_contact_image( $c, \@errors );

    my $emails = $self->_new_email_addresses( $c, \@errors );

    my $websites = $self->_new_websites( $c, \@errors );

    my $messaging = $self->_new_messaging_providers( $c, \@errors );

    my $addresses = $self->_new_addresses( $c, \@errors );

    my $phone_numbers = $self->_new_phone_numbers( $c, \@errors );

    my $custom_fields = $self->_custom_fields( $c, \@errors );

    my $members;
    if ( $class->can('members') ) {
        $members = $c->request()->members();
    }

    if (@errors) {
        my $e = R2::Exception::DataValidation->new( errors => \@errors );

        my ($type) = $class =~ /R2::Schema::(\w+)/;
        my $view = 'new_' . ( lc $type ) . '_form';

        $c->redirect_with_error(
            error     => $e,
            uri       => $c->account()->uri( view => $view ),
            form_data => $c->request()->params(),
        );
    }

    my $user    = $c->user();
    my $account = $c->account();

    my $insert_sub = sub {
        if ($image) {
            my $file = R2::Schema::File->insert(
                filename   => $image->basename(),
                contents   => scalar $image->slurp(),
                mime_type  => $image->type(),
                account_id => $contact_p->{account_id},
            );

            $contact_p->{image_file_id} = $file->file_id();
        }

        my $thing = $class->insert( %{$contact_p}, user => $user );
        my $contact = $thing->contact();

        $self->_update_or_add_contact_data(
            $contact,
            $contact->real_contact(),
            $user,
            $emails,
            undef,
            $websites,
            undef,
            $messaging,
            undef,
            $addresses,
            undef,
            $phone_numbers,
            undef,
            $members,
            $custom_fields,
        );

        my $note = $c->request()->params()->{note};
        if ( !string_is_empty($note) ) {
            $contact->add_note(
                note => $note,
                contact_note_type_id =>
                    $account->made_a_note_contact_note_type()
                    ->contact_note_type_id(),
                user_id => $user->user_id(),
            );
        }

        return $thing;
    };

    return R2::Schema->RunInTransaction($insert_sub);
}

sub _update_contact {
    my $self    = shift;
    my $c       = shift;
    my $contact = shift;

    my $real_contact = $contact->real_contact();
    my $class = blessed $real_contact;

    my $contact_p = $self->_contact_params_for_class( $c, $class );

    my @errors = $real_contact->validate_for_update( %{$contact_p} );

    my $image = $self->_contact_image( $c, \@errors );

    my $new_emails = $self->_new_email_addresses( $c, \@errors );
    my $updated_emails = $self->_updated_email_addresses( $c, \@errors );

    my $new_websites = $self->_new_websites( $c, \@errors );
    my $updated_websites = $self->_updated_websites( $c, \@errors );

    my $new_messaging = $self->_new_messaging_providers( $c, \@errors );
    my $updated_messaging = $self->_updated_messaging_providers( $c, \@errors );

    my $new_addresses = $self->_new_addresses( $c, \@errors );
    my $updated_addresses = $self->_updated_addresses( $c, \@errors );

    my $new_phone_numbers = $self->_new_phone_numbers( $c, \@errors );
    my $updated_phone_numbers = $self->_updated_phone_numbers( $c, \@errors );

    my $custom_fields = $self->_custom_fields( $c, \@errors );

    my $members;
    if ( $real_contact->can('members') ) {
        $members = $c->request()->members();
    }

    if (@errors) {
        my $e = R2::Exception::DataValidation->new( errors => \@errors );

        $c->redirect_with_error(
            error     => $e,
            uri       => '/contact/new_person_form',
            form_data => $c->request()->params(),
        );
    }

    my $user = $c->user();

    my $update_sub = sub {
        if ($image) {
            if ( my $old_image = $contact->image() ) {
                $old_image->file()->delete();
            }

            my $file = R2::Schema::File->insert(
                filename   => $image->basename(),
                contents   => scalar $image->slurp(),
                mime_type  => $image->type(),
                account_id => $contact->account_id(),
            );

            $contact_p->{image_file_id} = $file->file_id();
        }

        $real_contact->update( %{$contact_p}, user => $user );

        $self->_update_or_add_contact_data(
            $contact,
            $real_contact,
            $user,
            $new_emails,
            $updated_emails,
            $new_websites,
            $updated_websites,
            $new_messaging,
            $updated_messaging,
            $new_addresses,
            $updated_addresses,
            $new_phone_numbers,
            $updated_phone_numbers,
            $members,
            $custom_fields,
        );
    };

    return R2::Schema->RunInTransaction($update_sub);
}

sub _update_or_add_contact_data {
    my $self              = shift;
    my $contact           = shift;
    my $real_contact      = shift;
    my $user              = shift;
    my $new_emails        = shift;
    my $updated_emails    = shift;
    my $new_websites      = shift;
    my $updated_websites  = shift;
    my $new_messaging     = shift;
    my $updated_messaging = shift;
    my $new_addresses     = shift;
    my $updated_addresses = shift;
    my $new_numbers       = shift;
    my $updated_numbers   = shift;
    my $members           = shift;
    my $custom_fields     = shift;

    $contact->update_or_add_email_addresses(
        $updated_emails || {},
        $new_emails,
        $user,
    );

    $contact->update_or_add_websites(
        $updated_websites || {},
        $new_websites,
        $user,
    );

    $contact->update_or_add_messaging_providers(
        $updated_messaging || {},
        $new_messaging,
        $user,
    );

    $contact->update_or_add_addresses(
        $updated_addresses || {},
        $new_addresses,
        $user,
    );

    $contact->update_or_add_phone_numbers(
        $updated_numbers || {},
        $new_numbers,
        $user,
    );

    if ( $real_contact->can('members') ) {
        $real_contact->update_members(
            members => $members || [],
            user => $user,
        );
    }

    my %values = map { $_->[0]->custom_field_id() => $_->[1] } @{$custom_fields};

    for my $field ( $contact->custom_fields()->all() ) {
        if ( string_is_empty( $values{ $field->custom_field_id() } ) ) {
            $field->delete_value_for_contact( contact => $contact );
        }
    }

    for my $pair ( @{$custom_fields} ) {
        $pair->[0]->set_value_for_contact(
            contact => $contact,
            value   => $pair->[1]
        );
    }
}

__PACKAGE__->meta()->make_immutable();

1;
