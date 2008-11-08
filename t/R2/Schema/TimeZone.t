use strict;
use warnings;

use Test::More tests => 1;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Test::Config;
use R2::Config;
use R2::Schema::TimeZone;


my $dbh = mock_dbh();

{
    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} =
        [ [ qw( olson_name iso_code description display_order ) ],
          [ 'America/Chicago', 'us', 'Chi-town', 1 ],
          [ 'America/New_York', 'us', 'The Big Apple', 2 ],
        ];

    my $iter = R2::Schema::TimeZone->ByCountry('us');
    $iter->next();

    like( $dbh->{mock_all_history}[0]->statement(),
          qr/SELECT .+ FROM "TimeZone" WHERE "TimeZone"."iso_code" = \?/,
          'ByCountry() generates expected SQL' );
}
