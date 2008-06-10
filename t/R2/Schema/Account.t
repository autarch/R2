use strict;
use warnings;

use Test::More tests => 25;

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

{
    my $account =
        R2::Schema::Account->insert( name      => 'The Account',
                                     domain_id => 1,
                                   );

    $dbh->{mock_clear_history} = 1;

    $account->replace_donation_sources( 'Source1', 'Source2' );

    my @sql = map { $_->statement() } @{ $dbh->{mock_all_history} };

    is( scalar @sql, 5,
        '5 SQL statements were executed for replacing donation sources' );

    is( $sql[0], 'BEGIN WORK', 'first statement started a transaction' );
    is( $sql[1], 'DELETE FROM "DonationSource" WHERE "DonationSource"."account_id" = ?',
        'second statement was expected DELETE' );

    my $insert = q{INSERT INTO "DonationSource" ("account_id", "name") VALUES (?, ?)};
    is( $sql[2], $insert,
        'third statement was expected INSERT' );
    is( $sql[3], $insert,
        'fourth statement was expected INSERT' );

    is( $sql[4], 'COMMIT',
        'last statement was committed transaction' );
}

{
    my $account =
        R2::Schema::Account->insert( name      => 'The Account',
                                     domain_id => 1,
                                   );

    $dbh->{mock_clear_history} = 1;

    $account->replace_donation_targets( 'Target1', 'Target2' );

    my @sql = map { $_->statement() } @{ $dbh->{mock_all_history} };

    is( scalar @sql, 5,
        '5 SQL statements were executed for replacing donation targets' );

    is( $sql[0], 'BEGIN WORK', 'first statement started a transaction' );
    is( $sql[1], 'DELETE FROM "DonationTarget" WHERE "DonationTarget"."account_id" = ?',
        'second statement was expected DELETE' );

    my $insert = q{INSERT INTO "DonationTarget" ("account_id", "name") VALUES (?, ?)};
    is( $sql[2], $insert,
        'third statement was expected INSERT' );
    is( $sql[3], $insert,
        'fourth statement was expected INSERT' );

    is( $sql[4], 'COMMIT',
        'last statement was committed transaction' );
}

{
    my $account =
        R2::Schema::Account->insert( name      => 'The Account',
                                     domain_id => 1,
                                   );

    $dbh->{mock_clear_history} = 1;

    $account->replace_payment_types( 'Type1', 'Type2' );

    my @sql = map { $_->statement() } @{ $dbh->{mock_all_history} };

    is( scalar @sql, 5,
        '5 SQL statements were executed for replacing donation types' );

    is( $sql[0], 'BEGIN WORK', 'first statement started a transaction' );
    is( $sql[1], 'DELETE FROM "PaymentType" WHERE "PaymentType"."account_id" = ?',
        'second statement was expected DELETE' );

    my $insert = q{INSERT INTO "PaymentType" ("account_id", "name") VALUES (?, ?)};
    is( $sql[2], $insert,
        'third statement was expected INSERT' );
    is( $sql[3], $insert,
        'fourth statement was expected INSERT' );

    is( $sql[4], 'COMMIT',
        'last statement was committed transaction' );
}
