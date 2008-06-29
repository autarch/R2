use strict;
use warnings;

use Test::More tests => 3;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Schema::AddressType;


my $dbh = mock_dbh();

{
    eval
    {
        R2::Schema::AddressType->insert( name => 'Test' );
    };

    ok( $@, 'cannot create a new address type which does not apply to anything' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is( $e[0]->{message},
	q{An address type must apply to a person, household, or organization.},
        'got expected error message' );
}
