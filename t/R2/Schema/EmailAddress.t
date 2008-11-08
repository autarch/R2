use strict;
use warnings;

use Test::More tests => 6;

use lib 't/lib';
use R2::Test qw( mock_schema );

use R2::Schema::EmailAddress;


mock_schema();

{
    eval
    {
        R2::Schema::EmailAddress->insert( email_address => '@example.com',
                                          contact_id    => 1,
                                        );
    };

    ok( $@, 'cannot create a new email address with an invalid address' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is( $e[0]->{message}, q{"@example.com" is not a valid email address.},
        'got expected error message' );
}

{
    eval
    {
        R2::Schema::EmailAddress->insert( email_address => 'bob@not a domain.com',
                                          contact_id    => 1,
                                        );
    };

    ok( $@, 'cannot create a new email address with an invalid address' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is( $e[0]->{message}, q{"bob@not a domain.com" is not a valid email address.},
        'got expected error message' );
}
