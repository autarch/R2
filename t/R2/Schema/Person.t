use strict;
use warnings;

use Test::More tests => 6;

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

    ok( $person->party(), 'newly created person has a party' );
    is( $person->party()->party_id(), 1, 'party_id == 1' );
    is( $person->person_id(), $person->party()->party_id(), 'person_id == party_id' );

    is( $person->party()->email_address(), 'joe.smith@example.com',
        'data for party is passed through on person insert' );
    is( $person->email_address(), 'joe.smith@example.com',
        'attributes of party are available as person methods' );

    is( $person->first_name, 'Joe',
        'first_name == Joe' );
}
