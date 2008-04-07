use strict;
use warnings;

use Test::More tests => 10;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Schema::Person;


my $dbh = mock_dbh();

{
    my $person =
        R2::Schema::Person->insert( first_name    => 'Joe',
                                    last_name     => 'Smith',
                                    email_address => 'joe.smith@example.com',
                                    website       => 'http://example.com',
                                  );

    ok( $person->contact(), 'newly created person has a contact' );
    is( $person->contact()->contact_id(), 1, 'contact_id == 1' );
    is( $person->person_id(), $person->contact()->contact_id(), 'person_id == contact_id' );

    is( $person->contact()->email_address(), 'joe.smith@example.com',
        'data for contact is passed through on person insert' );
    is( $person->email_address(), 'joe.smith@example.com',
        'attributes of contact are available as person methods' );

    is( $person->first_name(), 'Joe',
        'first_name == Joe' );
    is( $person->friendly_name(), 'Joe',
        'friendly_name == Joe' );
}

{
    eval
    {
        R2::Schema::Person->insert( email_address => 'joe.smith@example.com',
                                    website       => 'http://example.com',
                                  );
    };

    ok( $@, 'cannot create a new person without a first or last name' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is( $e[0]->{message}, 'A person requires either a first or last name.',
        'got expected error message' );
}
