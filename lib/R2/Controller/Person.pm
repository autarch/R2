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


sub person : Chained('/account/_set_account') : PathPart('person') : Args(0) : ActionClass('+R2::Action::REST') { }

sub person_GET
{
    my $self = shift;
    my $c    = shift;

    my $name = $c->request()->parameters()->{person_name};

    my @people;
    if ( ! string_is_empty($name) )
    {
        my $people = R2::Search::Person::ByName->new( account => $c->account(),
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

    my $account = $c->account();

    unless ( $c->model('Authz')->user_can_add_contact( user    => $c->user(),
                                                       account => $account,
                                                     ) )
    {
        $c->_redirect_with_error
            ( error => 'You are not allowed to add contacts',
              uri   => $account->uri(),
            );
    }

    my %p = $c->request()->person_params();
    $p{account_id} = $account->account_id();
    $p{date_format} = $c->request()->params()->{date_format};

    my @errors = R2::Schema::Person->ValidateForInsert(%p);

    my $person =
        $self->_insert_contact
            ( $c,
              'R2::Schema::Person',
              \%p,
              \@errors,
            );

    $c->redirect_and_detach( $person->contact()->uri() );
}

no Moose;

1;
