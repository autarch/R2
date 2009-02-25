package R2::Role::Controller::ContactPOST;

use strict;
use warnings;

use R2::Schema::EmailAddress;
use R2::Schema::File;
use R2::Util qw( string_is_empty );

use Moose::Role;


sub _get_image
{
    my $self   = shift;
    my $c      = shift;
    my $errors = shift;

    my $image = $c->request()->upload('image');

    if ( $image && ! R2::Schema::File->TypeIsImage( $image->type() ) )
    {
        push @{ $errors }, { field   => 'image',
                             message => 'The image you provided is not a GIF, JPG, or PNG.',
                           };
    }

    return $image;
}

sub _get_email_addresses
{
    my $self   = shift;
    my $c      = shift;
    my $errors = shift;

    my $emails = $c->request()->new_email_address_param_sets();

    for my $suffix ( keys %{ $emails } )
    {
        my @e =
            R2::Schema::EmailAddress->ValidateForInsert
                    ( %{ $emails->{$suffix} },
                      contact_id => 1,
                    );

        $self->_apply_suffix_to_fields_in_errors( $suffix, \@e );

        push @{ $errors }, @e;
    }

    return [ values %{ $emails } ];
}

sub _get_websites
{
    my $self   = shift;
    my $c      = shift;
    my $errors = shift;

    my $sites = $c->request()->new_website_param_sets();

    for my $suffix ( keys %{ $sites } )
    {
        my @e =
            R2::Schema::Website->ValidateForInsert
                ( %{ $sites->{$suffix} },
                  contact_id => 1,
                );

        $self->_apply_suffix_to_fields_in_errors( $suffix, \@e );

        push @{ $errors }, @e;
    }

    return [ values %{ $sites } ];
}

sub _get_addresses
{
    my $self   = shift;
    my $c      = shift;
    my $errors = shift;

    my $addresses = $c->request()->new_address_param_sets();

    for my $suffix ( keys %{ $addresses } )
    {
        my @e =
            R2::Schema::Address->ValidateForInsert
                ( %{ $addresses->{$suffix} },
                  contact_id => 1,
                );

        $self->_apply_suffix_to_fields_in_errors( $suffix, \@e );

        push @{ $errors }, @e;
    }

    return [ values %{ $addresses } ];
}

sub _get_phone_numbers
{
    my $self   = shift;
    my $c      = shift;
    my $errors = shift;

    my $numbers = $c->request()->new_phone_number_param_sets();

    for my $suffix ( keys %{ $numbers } )
    {
        my @e =
            R2::Schema::PhoneNumber->ValidateForInsert
                ( %{ $numbers->{$suffix} },
                  contact_id => 1,
                );

        $self->_apply_suffix_to_fields_in_errors( $suffix, \@e );

        push @{ $errors }, @e;
    }

    return [ values %{ $numbers } ];
}

sub _get_custom_fields
{
    my $self   = shift;
    my $c      = shift;
    my $errors = shift;

    my %values = $c->request()->custom_field_values();

    my @fields;
    for my $id ( keys %values )
    {
        my $field = R2::Schema::CustomField->new( custom_field_id => $id );

        $values{$id} = $field->clean_value( $values{$id} );

        if ( my @e = $field->validate_value( $values{$id} ) )
        {
            push @{ $errors }, @e;
            next;
        }

        if ( $field->is_required() && string_is_empty( $values{$id} ) )
        {
            push @{ $errors },
                { message => 'The ' . $field->label() . ' field is required.',
                  field   => 'custom_field_' . $field->custom_field_id(),
                };

            next;
        }

        next if string_is_empty( $values{$id} );

        push @fields, [ $field, $values{$id} ];
    }

    return \@fields
}

sub _apply_suffix_to_fields_in_errors
{
    my $self    = shift;
    my $suffix  = shift;
    my $errors = shift;

    for my $e ( @{ $errors } )
    {
        if ( ref $e && $e->{field} )
        {
            $e->{field} .= q{-} . $suffix;
        }
    }
}

sub _insert_contact
{
    my $self   = shift;
    my $c      = shift;
    my $class  = shift;
    my $p      = shift;
    my $errors = shift;

    my $image = $self->_get_image( $c, $errors );

    my $emails = $self->_get_email_addresses( $c, $errors );

    my $websites = $self->_get_websites( $c, $errors );

    my $addresses = $self->_get_addresses( $c, $errors );

    my $phone_numbers = $self->_get_phone_numbers( $c, $errors );

    my $custom_fields = $self->_get_custom_fields( $c, $errors );

    my $members;
    if ( $class->can('members') )
    {
        $members = $c->request()->members();
    }

    if ( @{ $errors } )
    {
        my $e = R2::Exception::DataValidation->new( errors => $errors );

        $c->_redirect_with_error( error  => $e,
                                  uri    => '/contact/new_person_form',
                                  params => $c->request()->params(),
                                );
    }

    my $insert_sub =
        $self->_make_insert_sub( $c,
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

sub _make_insert_sub
{
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

    return
        sub
        {
            if ($image)
            {
                my $file =
                    R2::Schema::File->insert
                        ( filename   => $image->basename(),
                          contents   => scalar $image->slurp(),
                          mime_type  => $image->type(),
                          account_id => $contact_p->{account_id},
                        );

                $contact_p->{image_file_id} = $file->file_id();
            }

            my $thing = $class->insert( %{ $contact_p }, user => $user );
            my $contact = $thing->contact();

            for my $email ( @{ $emails } )
            {
                $contact->add_email_address( %{ $email }, user => $user );
            }

            for my $website ( @{ $websites } )
            {
                $contact->add_website( %{ $website }, user => $user );
            }

            for my $address ( @{ $addresses } )
            {
                $contact->add_address( %{ $address }, user => $user );
            }

            for my $number ( @{ $phone_numbers } )
            {
                $contact->add_phone_number( %{ $number }, user => $user );
            }

            if ($members)
            {
                for my $member ( @{ $members } )
                {
                    $thing->add_member( %{ $member }, user => $user );
                }
            }

            my $note = $c->request()->params()->{note};
            if ( ! string_is_empty($note) )
            {
                $contact->add_note
                    ( note => $note,
                      contact_note_type_id =>
                          $account->made_a_note_contact_note_type()
                                  ->contact_note_type_id(),
                      user_id => $c->user()->user_id(),
                    );
            }

            for my $pair ( @{ $custom_fields } )
            {
                $pair->[0]->set_value_for_contact( contact => $contact, value => $pair->[1] );
            }

            return $thing;
        };
}

no Moose::Role;

1;
