use strict;
use warnings;

use Test::More;

use lib 't/lib';

use R2::Test::RealSchema;

use R2::Schema::TimeZone;

{
    my $iter = R2::Schema::TimeZone->ByCountry('us');

    is_deeply(
        [ map { $_->olson_name() } $iter->all() ],
        [
            qw(
                America/New_York
                America/Chicago
                America/Denver
                America/Los_Angeles
                America/Anchorage
                America/Adak
                Pacific/Honolulu
                America/Santo_Domingo
                Pacific/Guam
                )
        ],
        'time zones for us'
    );
}

done_testing();
