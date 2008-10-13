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
    use Data::Dumper; warn Dumper \$addresses;
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
        $self->_make_insert_sub( $c->user(),
                                 $class,
                                 $p,
                                 $image,
                                 $emails,
                                 $websites,
                                 $addresses,
                                 $phone_numbers,
                                 $members,
                               );

    return R2::Schema->RunInTransaction($insert_sub);
}

sub _make_insert_sub
{
    my $self          = shift;
    my $user          = shift;
    my $class         = shift;
    my $p             = shift;
    my $image         = shift;
    my $emails        = shift;
    my $websites      = shift;
    my $addresses     = shift;
    my $phone_numbers = shift;
    my $members       = shift;

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

            my $thing = $class->insert( %{ $p }, user => $user );
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
                    $thing->add_member( %{ $member } );
                }
            }

            return $thing;
        };
}

no Moose::Role;

1;
