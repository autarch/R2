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

    my $format = $c->request()->params()->{date_format};
    $p{date_format} = $format if defined $format;

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

for my $class_suffix (qw( EmailAddress Website Address PhoneNumber )) {
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

sub _new_custom_fields {
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

    my $p = $self->_contact_params_for_class( $c, $class );

    my @errors = $class->ValidateForInsert( %{$p} );

    my $image = $self->_contact_image( $c, \@errors );

    my $emails = $self->_new_email_addresses( $c, \@errors );

    my $websites = $self->_new_websites( $c, \@errors );

    my $addresses = $self->_new_addresses( $c, \@errors );

    my $phone_numbers = $self->_new_phone_numbers( $c, \@errors );

    my $custom_fields = $self->_new_custom_fields( $c, \@errors );

    my $members;
    if ( $class->can('members') ) {
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

    my $insert_sub = $self->_make_insert_sub(
        $c,
        $class,
        $p,
        $image,
        $emails,
        $websites,
        $addresses,
        $phone_numbers,
        $members,
        $custom_fields,
    );

    return R2::Schema->RunInTransaction($insert_sub);
}

sub _make_insert_sub {
    my $self          = shift;
    my $c             = shift;
    my $class         = shift;
    my $contact_p     = shift;
    my $image         = shift;
    my $emails        = shift;
    my $websites      = shift;
    my $addresses     = shift;
    my $phone_numbers = shift;
    my $members       = shift;
    my $custom_fields = shift;

    my $user    = $c->user();
    my $account = $c->account();

    return sub {
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

        for my $email ( @{$emails} ) {
            $contact->add_email_address( %{$email}, user => $user );
        }

        for my $website ( @{$websites} ) {
            $contact->add_website( %{$website}, user => $user );
        }

        for my $address ( @{$addresses} ) {
            $contact->add_address( %{$address}, user => $user );
        }

        for my $number ( @{$phone_numbers} ) {
            $contact->add_phone_number( %{$number}, user => $user );
        }

        if ($members) {
            for my $member ( @{$members} ) {
                $thing->add_member( %{$member}, user => $user );
            }
        }

        my $note = $c->request()->params()->{note};
        if ( !string_is_empty($note) ) {
            $contact->add_note(
                note => $note,
                contact_note_type_id =>
                    $account->made_a_note_contact_note_type()
                    ->contact_note_type_id(),
                user_id => $c->user()->user_id(),
            );
        }

        for my $pair ( @{$custom_fields} ) {
            $pair->[0]->set_value_for_contact(
                contact => $contact,
                value   => $pair->[1]
            );
        }

        return $thing;
    };
}

sub _update_contact {
    my $self    = shift;
    my $c       = shift;
    my $contact = shift;

    my $real_contact = $contact->real_contact();
    my $class = blessed $real_contact;

    my $p = $self->_contact_params_for_class( $c, $class );

    my @errors = $real_contact->validate_for_update( %{$p} );

    my $image = $self->_contact_image( $c, \@errors );

    my $new_emails = $self->_new_email_addresses( $c, \@errors );
    my $updated_emails = $self->_updated_email_addresses( $c, \@errors );

    my $new_websites = $self->_new_websites( $c, \@errors );
    my $updated_websites = $self->_updated_websites( $c, \@errors );

    my $new_addresses = $self->_new_addresses( $c, \@errors );
    my $updated_addresses = $self->_updated_addresses( $c, \@errors );

    my $new_phone_numbers = $self->_new_phone_numbers( $c, \@errors );
    my $updated_phone_numbers = $self->_updated_phone_numbers( $c, \@errors );

    my $new_custom_fields = $self->_new_custom_fields( $c, \@errors );

    my $new_members;
    if ( $real_contact->can('members') ) {
        $new_members = $c->request()->members();
    }

    my $updated_members;

    if (@errors) {
        my $e = R2::Exception::DataValidation->new( errors => \@errors );

        $c->redirect_with_error(
            error     => $e,
            uri       => '/contact/new_person_form',
            form_data => $c->request()->params(),
        );
    }

    my $update_sub = $self->_make_update_sub(
        $c,
        $contact,
        $p,
        $image,
        $new_emails,
        $updated_emails,
        $new_websites,
        $updated_websites,
        $new_addresses,
        $updated_addresses,
        $new_phone_numbers,
        $updated_phone_numbers,
        $new_members,
        $updated_members,
        $new_custom_fields,
    );

    return R2::Schema->RunInTransaction($update_sub);
}

sub _make_update_sub {
    my $self                  = shift;
    my $c                     = shift;
    my $contact               = shift;
    my $contact_p             = shift;
    my $image                 = shift;
    my $new_emails            = shift;
    my $updated_emails        = shift;
    my $new_websites          = shift;
    my $updated_websites      = shift;
    my $new_addresses         = shift;
    my $updated_addresses     = shift;
    my $new_phone_numbers     = shift;
    my $updated_phone_numbers = shift;
    my $new_members           = shift;
    my $updated_members       = shift;
    my $custom_fields         = shift;

    my $user    = $c->user();
    my $account = $c->account();

    return sub {
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

        $contact->real_contact()->update( %{$contact_p}, user => $user );

        for my $email ( @{$new_emails} ) {
            $contact->add_email_address( %{$email}, user => $user );
        }

        for my $email_address_id ( keys %{$updated_emails} ) {
            my $email = R2::Schema::EmailAddress->new(
                email_address_id => $email_address_id,
            ) or next;

            $email->update( %{ $updated_emails->{$email_address_id} } );
        }

        for my $website ( @{$new_websites} ) {
            $contact->add_website( %{$website}, user => $user );
        }

        for my $website_id ( keys %{$updated_websites} ) {
            my $website = R2::Schema::Website->new(
                website_id => $website_id,
            ) or next;

            $website->update( %{ $updated_websites->{$website_id} } );
        }

        for my $address ( @{$new_addresses} ) {
            $contact->add_address( %{$address}, user => $user );
        }

        for my $address_id ( keys %{$updated_addresses} ) {
            my $address = R2::Schema::Address->new(
                address_id => $address_id,
            ) or next;

            $address->update( %{ $updated_addresses->{$address_id} } );
        }

        for my $number ( @{$new_phone_numbers} ) {
            $contact->add_phone_number( %{$number}, user => $user );
        }

        for my $phone_number_id ( keys %{$updated_phone_numbers} ) {
            my $phone_number = R2::Schema::PhoneNumber->new(
                phone_number_id => $phone_number_id,
            ) or next;

            $phone_number->update(
                %{ $updated_phone_numbers->{$phone_number_id} } );
        }

        if ($new_members) {
            for my $member ( @{$new_members} ) {
                $contact->add_member( %{$member}, user => $user );
            }
        }

        # XXX - updated_members

        # XXX - how to delete a custom field value?
        for my $pair ( @{$custom_fields} ) {
            $pair->[0]->set_value_for_contact(
                contact => $contact,
                value   => $pair->[1]
            );
        }
    };
}

1;
