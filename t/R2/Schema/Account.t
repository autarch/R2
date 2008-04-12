use strict;
use warnings;

use Test::More tests => 4;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Schema::Account;


my $dbh = mock_dbh();

{
    $dbh->{mock_add_resultset} =
        { sql     => q{SELECT "Country"."name" FROM "Country" WHERE "Country"."iso_code" = ?},
          results => [ [ qw( name ) ],
                       [ 'United States' ],
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

    ok( ( grep { $_ =~ /INSERT INTO "Fund"/ } @inserts ),
        'at least one Fund was inserted for a new account' );
    ok( ( grep { $_ =~ /INSERT INTO "AddressType"/ } @inserts ),
        'at least one AddressType was inserted for a new account' );
    ok( ( grep { $_ =~ /INSERT INTO "PhoneNumberType"/ } @inserts ),
        'at least one PhoneNumberType was inserted for a new account' );
    ok( ( grep { $_ =~ /INSERT INTO "MessagingProvider"/ } @inserts ),
        'at least one MessagingProvider was inserted for a new account' );
}
