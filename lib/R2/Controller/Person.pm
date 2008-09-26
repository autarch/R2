package R2::Controller::Person;

use strict;
use warnings;

use base 'R2::Controller::Base';

use R2::Schema::Person;
use R2::Search::Person::ByName;
use R2::Util qw( string_is_empty );


sub person : Path('') : ActionClass('+R2::Action::REST') { }

sub person_GET
{
    my $self = shift;
    my $c    = shift;

    my $name = $c->request()->parameters()->{person_name};

    my @people;
    if ( ! string_is_empty($name) )
    {
        my $people = R2::Search::Person::ByName->new( account => $c->user()->account(),
                                                      name    => $name,
                                                    )->people();

        while ( my $person = $people->next() )
        {
            push @people, { name      => $person->full_name(),
                            person_id => $person->person_id(),
                          };
        }
    }

    return
        $self->status_ok( $c,
                          entity => \@people,
                        );
}

sub person_POST
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

    my %p = $c->request()->person_params();
    $p{account_id} = $c->user()->account_id();
    $p{date_format} = $c->request()->params()->{date_format};

    my @errors = R2::Schema::Person->ValidateForInsert(%p);

    my $image = $self->_get_image( $c, \@errors );

    if (@errors)
    {
        my $e = R2::Exception::DataValidation->new( errors => \@errors );

        $c->_redirect_with_error( error  => $e,
                                  uri    => '/contact/new_person_form',
                                  params => $c->request()->params(),
                                );
    }

    my @addresses = $c->request()->new_address_param_sets();

    my @phone_numbers = $c->request()->new_phone_number_param_sets();

    my $person;
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

            $person = R2::Schema::Person->insert(%p);

            for my $email (@email_addresses)
            {
                R2::Schema::EmailAddress->insert( %{ $email },
                                                  contact_id => $person->contact_id(),
                                                );
            }

            for my $address (@addresses)
            {
                R2::Schema::Address->insert( %{ $address },
                                             contact_id => $person->contact_id(),
                                           );
            }

            for my $number (@phone_numbers)
            {
                R2::Schema::PhoneNumber->insert( %{ $number },
                                                 contact_id => $person->contact_id(),
                                               );
            }
        };

    R2::Schema->RunInTransaction($insert_sub);

    $c->redirect_and_detach( $c->uri_for( '/contact/' . $person->contact_id() ) );
}

1;
