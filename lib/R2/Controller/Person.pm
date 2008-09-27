package R2::Controller::Person;

use strict;
use warnings;

use R2::Schema::Address;
use R2::Schema::EmailAddress;
use R2::Schema::Person;
use R2::Schema::PhoneNumber;
use R2::Schema::Website;
use R2::Search::Person::ByName;
use R2::Util qw( string_is_empty );

use Moose;

BEGIN { extends 'R2::Controller::Base' }

with 'R2::Role::Controller::ContactPOST';


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

    my $person =
        $self->_insert_contact
            ( $c,
              'R2::Schema::Person',
              \%p,
              \@errors,
            );

    $c->redirect_and_detach( $c->uri_for( '/contact/' . $person->contact_id() ) );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
