use strict;
use warnings;

use Test::More tests => 25;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Schema::Person;


my $dbh = mock_dbh();

{
    my $person =
        R2::Schema::Person->insert( salutation    => '',
                                    first_name    => 'Joe',
                                    middle_name   => '',
                                    last_name     => 'Smith',
                                    suffix        => '',
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
    is( $person->full_name(), 'Joe Smith',
        'full_name == Joe Smith' );
}

{
    my $person =
        R2::Schema::Person->insert( salutation  => 'Sir',
                                    first_name  => 'Joe',
                                    middle_name => 'J.',
                                    last_name   => 'Smith',
                                    suffix      => 'the 23rd',
                                  );

    is( $person->full_name(), 'Sir Joe J. Smith the 23rd',
        'full_name == Sir Joe J. Smith the 23rd' );
}

{
    my @errors =
        R2::Schema::Person->ValidateForInsert( email_address => 'joe.smith@example.com',
                                               website       => 'http://example.com',
                                             );

    is( scalar @errors, 1, 'got one validation error' );
    is( $errors[0]->{message}, 'A person requires either a first or last name.',
        'got expected error message' );
}

{
    my $person =
        R2::Schema::Person->insert( salutation  => 'Sir',
                                    first_name  => 'Joe',
                                    middle_name => 'J.',
                                    last_name   => 'Smith',
                                    suffix      => 'the 23rd',
                                  );

    my @errors =
        $person->validate_for_update( first_name => '',
                                      last_name  => '',
                                    );

    is( scalar @errors, 1, 'got one validation error' );
    is( $errors[0]->{message}, 'A person requires either a first or last name.',
        'got expected error message' );
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

{
    eval
    {
        R2::Schema::Person->insert( first_name    => 'Joe',
                                    email_address => 'joe.smith@',
                                  );
    };

    ok( $@, 'cannot create a new person with an invalid email address' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is( $e[0]->{message}, q{"joe.smith@" is not a valid email address.},
        'got expected error message' );
}

{
    my $dt = DateTime->today()->add( days => 10 );

    eval
    {
        R2::Schema::Person->insert( first_name  => 'Dave',
                                    birth_date  => $dt->strftime( '%Y-%m-%d' ),
                                    date_format => '%Y-%m-%d',
                                  );
    };

    ok( $@, 'cannot create a new person with a future birth date' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is( $e[0]->{message}, q{Birth date cannot be in the future.},
        'got expected error message' );
}

{
    my $dt = DateTime->today()->add( days => 10 );

    eval
    {
        R2::Schema::Person->insert( first_name  => 'Dave',
                                    birth_date  => '01-03-1973',
                                    date_format => '%Y-%m-%d',
                                  );
    };

    ok( $@, 'cannot create a new person with an unparseable birth date' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is( $e[0]->{message}, q{Birth date does not seem to be a valid date.},
        'got expected error message' );
}
