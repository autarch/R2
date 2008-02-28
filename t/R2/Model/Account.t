use strict;
use warnings;

use Test::More tests => 4;

use R2::Model::Account;

use lib 't/lib';
use R2::Test qw( mock_dbh );


my $dbh = mock_dbh();

{
    my $account =
        R2::Model::Account->insert( name      => 'The Account',
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
