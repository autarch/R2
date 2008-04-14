use strict;
use warnings;

use Test::More tests => 6;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Schema::Contact;


{
    eval
    {
        R2::Schema::Contact->insert( contact_type  => 'Contact',
                                     email_address => '@example.com',
                                   );
    };

    ok( $@, 'cannot create a new contact with an invalid email address' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is( $e[0]->{message}, q{"@example.com" is not a valid email address.},
        'got expected error message' );
}

{
    eval
    {
        R2::Schema::Contact->insert( contact_type  => 'Contact',
                                     email_address => 'bob@not a domain.com',
                                   );
    };

    ok( $@, 'cannot create a new contact with an invalid email address' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is( $e[0]->{message}, q{"bob@not a domain.com" is not a valid email address.},
        'got expected error message' );
}
