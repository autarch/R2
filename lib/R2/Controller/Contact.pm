package R2::Controller::Contact;

use strict;
use warnings;

use base 'R2::Controller::Base';

use R2::Schema;
use R2::Schema::Address;
use R2::Schema::Contact;
use R2::Schema::File;
use R2::Schema::Person;
use R2::Schema::PhoneNumber;


sub new_person_form : Local
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

    $c->stash()->{template} = '/person/new_person_form';
}

sub new_household_form : Local
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

    $c->stash()->{template} = '/household/new_household_form';
}

sub new_person : Path('/person') : ActionClass('+R2::Action::REST') { }

sub new_person_POST
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

    my $image = $c->request()->upload('image');

    my @errors = R2::Schema::Person->ValidateForInsert(%p);

    if ( $image && ! R2::Schema::File->TypeIsImage( $image->type() ) )
    {
        push @errors, { field   => 'image',
                        message => 'The image you provided is not a GIF, JPG, or PNG.',
                      };
    }

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

sub _set_contact : Chained('/') : PathPart('contact') : CaptureArgs(1)
{
    my $self       = shift;
    my $c          = shift;
    my $contact_id = shift;

    my $contact = R2::Schema::Contact->new( contact_id => $contact_id );

    $c->redirect_and_detach('/')
        unless $contact;

    unless ( $c->model('Authz')->user_can_view_contact( user    => $c->user(),
                                                        contact => $contact,
                                                      ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not authorized to view this contact',
              uri   => $c->uri_for('/'),
            );
    }

    $c->stash()->{contact} = $contact;
}

sub contact : Chained('_set_contact') : PathPart('') : Args(0) : ActionClass('+R2::Action::REST') { }

sub contact_GET_html : Private
{
    my $self = shift;
    my $c    = shift;

    my $contact = $c->stash()->{contact};

    my $meth = '_display_' . lc $contact->contact_type();
    $self->$meth($c);
}

sub _display_person
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{person} = $c->stash()->{contact}->person();

    $c->stash()->{template} = '/person/view';
}

1;
