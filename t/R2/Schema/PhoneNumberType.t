use strict;
use warnings;

use Test::More;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Schema::PhoneNumberType;

my $dbh = mock_dbh();

{
    eval { R2::Schema::PhoneNumberType->insert( name => 'Test' ); };

    ok( $@,
        'cannot create a new phone number type which does not apply to anything'
    );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is(
        $e[0]->{message},
        q{A phone number type must apply to a person, household, or organization.},
        'got expected error message'
    );
}

done_testing();
