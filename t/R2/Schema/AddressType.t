use strict;
use warnings;

use Test::More tests => 7;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use List::Util qw( first );
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
        '... got an appropriate error message in the exception' );
}

{
    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_insert_id} = 1;

    my $type =
        R2::Schema::AddressType->insert( name => 'Test',
                                         applies_to_person       => 0,
                                         applies_to_household    => 0,
                                         applies_to_organization => 1,
                                         account_id              => 42,
                                       );

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} =
        [ [ 'count' ],
          [ 0 ],
        ];

    $dbh->{mock_add_resultset} =
        [ [ 'count' ],
          [ 0 ],
        ];

    eval
    {
        $type->update( applies_to_organization => 0 );
    };

    ok( $@, 'cannot update an address type so that it does not apply to anything' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is( $e[0]->{message},
	q{An address type must apply to a person, household, or organization.},
        '... got an appropriate error message in the exception' );
}

{
    my $type =
        R2::Schema::AddressType->insert( name => 'Test',
                                         applies_to_person       => 1,
                                         applies_to_household    => 1,
                                         applies_to_organization => 1,
                                         account_id              => 42,
                                       );

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} =
        [ [ 'count' ],
          [ 10 ],
        ];

    $dbh->{mock_add_resultset} =
        [ [ 'count' ],
          [ 0 ],
        ];

    $dbh->{mock_add_resultset} =
        [ [ 'count' ],
          [ 0 ],
        ];

    $type->update( applies_to_person    => 0,
                   applies_to_household => 0,
                 );

    my $update =
        first { $_->statement() =~ /^UPDATE/ } @{ $dbh->{mock_all_history} };

    is_deeply( $update->bound_params(),
               [ 0, 2 ],
               'trying to update an address type so it no longer applies to a type'
               . ' for which it has addresses silently ignores that part of the update.'
             );
}
