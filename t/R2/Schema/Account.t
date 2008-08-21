use strict;
use warnings;

use Test::More tests => 7;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Schema::Account;


my $dbh = mock_dbh();

{
    $dbh->{mock_add_resultset} =
        { sql     => q{SELECT "Country"."name" FROM "Country" WHERE "Country"."iso_code" = ?},
          results => [ [ qw( name ) ],
                       [ 'United States' ],
                       [ qw( name ) ],
                       [ 'Canada' ],
                     ],
        };

    my $account =
        R2::Schema::Account->insert( name      => 'The Account',
                                     domain_id => 1,
                                   );

    my @inserts =
        grep { /^INSERT/ }
        map { $_->statement() }
        @{ $dbh->{mock_all_history} };

    for my $table ( qw( DonationSource DonationTarget PaymentType
                        AddressType PhoneNumberType MessagingProvider
                        AccountCountry ) )
    {
        ok( ( grep { $_ =~ /INSERT INTO "\Q$table\E"/ } @inserts ),
            "at least one $table was inserted for a new account" );
    }
}
