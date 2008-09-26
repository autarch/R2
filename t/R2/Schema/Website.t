use strict;
use warnings;

use Test::More tests => 7;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Schema::Website;

mock_dbh();


{
    my $contact = R2::Schema::Website->insert( uri        => 'urth.org',
                                               contact_id => 1,
                                             );

    is( $contact->uri(), 'http://urth.org/',
        'uri gets canonicalized with a scheme if needed' );
}


{
    eval
    {
        my $contact = R2::Schema::Website->insert( uri        => 'urth',
                                                   contact_id => 1,
                                                 );
    };

    ok( $@, 'cannot create a new email address with an invalid address' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is( $e[0]->{message}, q{"urth" is not a valid web address.},
        'got expected error message' );
}

{
    eval
    {
        my $contact = R2::Schema::Website->insert( uri        => 'http://urth.foo',
                                                   contact_id => 1,
                                                 );
    };

    ok( $@, 'cannot create a new email address with an invalid address' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is( $e[0]->{message}, q{"http://urth.foo" is not a valid web address.},
        'got expected error message' );
}
