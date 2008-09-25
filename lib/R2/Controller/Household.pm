package R2::Controller::Household;

use strict;
use warnings;

use base 'R2::Controller::Base';

use R2::Schema::Household;
use R2::Util qw( string_is_empty );


sub household : Path('') : ActionClass('+R2::Action::REST') { }

sub household_POST
{
    my $self = shift;
    my $c    = shift;

    unless ( $c->model('Authz')->user_can_add_contact( user    => $c->user(),
                                                       account => $c->user()->account(),
                                                     ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not allowed to add contacts',
              uri   => $c->uri_for('/'),
            );
    }

    my %p = $c->request()->household_params();
    $p{account_id} = $c->user()->account_id();

    my @errors = R2::Schema::Household->ValidateForInsert(%p);

    my $image = $self->_get_image( $c, \@errors );

    my @members = $c->request()->members();

    unless (@members)
    {
        push @errors, { field   => 'member-search-text',
                        message => 'A household must have at least one member.',
                      };
    }

    if (@errors)
    {
        my $e = R2::Exception::DataValidation->new( errors => \@errors );

        $c->_redirect_with_error( error  => $e,
                                  uri    => '/contact/new_household_form',
                                  params => $c->request()->params(),
                                );
    }

    my @addresses = $c->request()->new_address_param_sets();

    my @phone_numbers = $c->request()->new_phone_number_param_sets();

    my $household;
    my $insert_sub =
        sub
        {
            if ($image)
            {
                my $file =
                    R2::Schema::File->insert
                        ( filename   => $image->basename(),
                          contents   => scalar $image->slurp(),
                          mime_type  => $image->type(),
                          account_id => $p{account_id},
                        );

                $p{image_file_id} = $file->file_id();
            }

            $household = R2::Schema::Household->insert(%p);

            for my $member (@members)
            {
                $household->add_member( %{ $member } )
            }

            for my $address (@addresses)
            {
                R2::Schema::Address->insert( %{ $address },
                                             contact_id => $household->contact_id(),
                                           );
            }

            for my $number (@phone_numbers)
            {
                R2::Schema::PhoneNumber->insert( %{ $number },
                                                 contact_id => $household->contact_id(),
                                               );
            }
        };

    R2::Schema->RunInTransaction($insert_sub);

    $c->redirect_and_detach( $c->uri_for( '/contact/' . $household->contact_id() ) );
}

1;
