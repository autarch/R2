package R2::Role::Controller::ContactPOST;

use strict;
use warnings;

use R2::Schema::EmailAddress;
use R2::Schema::File;

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

    if ( @{ $errors } )
    {
        my $e = R2::Exception::DataValidation->new( errors => $errors );

        $c->_redirect_with_error( error  => $e,
                                  uri    => '/contact/new_person_form',
                                  params => $c->request()->params(),
                                );
    }

    my $insert_sub =
        $self->_make_insert_sub( $class,
                                 $p,
                                 $image,
                                 $emails,
                                 $websites,
                                 $addresses,
                                 $phone_numbers,
                               );

    return R2::Schema->RunInTransaction($insert_sub);
}

sub _make_insert_sub
{
    my $self          = shift;
    my $class         = shift;
    my $p             = shift;
    my $image         = shift;
    my $emails        = shift;
    my $websites      = shift;
    my $addresses     = shift;
    my $phone_numbers = shift;

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
                          account_id => $p->{account_id},
                        );

                $p->{image_file_id} = $file->file_id();
            }

            my $contact = $class->insert( %{ $p } );

            for my $email ( @{ $emails } )
            {
                R2::Schema::EmailAddress->insert( %{ $email },
                                                  contact_id => $contact->contact_id(),
                                                );
            }

            for my $website ( @{ $websites } )
            {
                R2::Schema::Website->insert( %{ $website },
                                             contact_id => $contact->contact_id(),
                                           );
            }

            for my $address ( @{ $addresses } )
            {
                R2::Schema::Address->insert( %{ $address },
                                             contact_id => $contact->contact_id(),
                                           );
            }

            for my $number ( @{ $phone_numbers } )
            {
                R2::Schema::PhoneNumber->insert( %{ $number },
                                                 contact_id => $contact->contact_id(),
                                               );
            }

            return $contact;
        };
}

no Moose::Role;

1;
