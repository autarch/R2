package R2::Role::Controller::ContactCRUD;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema::EmailAddress;
use R2::Schema::File;
use R2::Util qw( string_is_empty studly_to_calm );
use Scalar::Util qw( blessed );

use Moose::Role;

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

1;
