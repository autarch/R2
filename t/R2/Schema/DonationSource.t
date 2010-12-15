use strict;
use warnings;

use Test::More;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Schema::DonationSource;

my $dbh = mock_dbh();

{
    my $source = R2::Schema::DonationSource->new(
        donation_source_id => 1,
        name               => 'Source',
        account_id         => 1,
        _from_query        => 1,
    );

    $dbh->{mock_add_resultset} = [
        [qw( FUNCTION0 )],
        [2],
    ];

    is(
        $source->donation_count(), 2,
        'donation_count() is 2'
    );
    is(
        $dbh->{mock_all_history}[0]->statement(),
        q{SELECT COUNT("Donation"."donation_id") AS "FUNCTION0" FROM "Donation" WHERE "Donation"."donation_source_id" = ?},
        'executed expected SELECT'
    );
}

done_testing();
