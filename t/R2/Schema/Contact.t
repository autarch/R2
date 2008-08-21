use strict;
use warnings;

use Test::More tests => 7;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Schema::Contact;

# Just needed so we have a data source for the insert later.
mock_dbh();

{
    eval
    {
        R2::Schema::Contact->insert( contact_type  => 'Contact',
                                     email_address => '@example.com',
                                     account_id    => 1,
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
                                     account_id    => 1,
                                   );
    };

    ok( $@, 'cannot create a new contact with an invalid email address' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is( $e[0]->{message}, q{"bob@not a domain.com" is not a valid email address.},
        'got expected error message' );
}

{
    my %c = ( contact_type  => 'Contact',
              email_address => 'bob@example.com',
              website       => 'urth.org',
              account_id    => 1,
            );

    my $contact = R2::Schema::Contact->insert(%c);

    is( $contact->website(), 'http://urth.org/',
        'website gets canonicalized with a scheme if needed' );
}
