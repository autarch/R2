package R2::Controller::Person;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema::Address;
use R2::Schema::EmailAddress;
use R2::Schema::Person;
use R2::Schema::PhoneNumber;
use R2::Schema::Website;
use R2::Search::Person;
use R2::Util qw( string_is_empty );

use Moose;
use CatalystX::Routes;

BEGIN { extends 'R2::Controller::Base' }

with 'R2::Role::Controller::ContactCRUD';

get people
    => chained '/account/_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my $name = $c->request()->parameters()->{person_name};

    my @people;
    if ( !string_is_empty($name) ) {
        my $people = R2::Search::Person->new(
            account      => $c->account(),
            restrictions => 'Contact::ByName',
            name         => $name,
        )->people();

        while ( my $person = $people->next() ) {
            push @people, $person->serialize();
        }
    }

    return $self->status_ok(
        $c,
        entity => \@people,
    );
};

post people
    => chained '/account/_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'can_add_contact',
        { account => $c->account() },
        'You are not allowed to add contacts.',
        $c->account()->uri(),
    );

    my $person = $self->_insert_contact(
        $c,
        'R2::Schema::Person',
    );

    $c->redirect_and_detach( $person->contact()->uri() );
};

__PACKAGE__->meta()->make_immutable();

1;
