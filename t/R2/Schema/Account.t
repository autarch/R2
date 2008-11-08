use strict;
use warnings;

use Test::More tests => 14;

use lib 't/lib';
use R2::Test qw( mock_schema );

use List::MoreUtils qw( all );

use R2::Schema::Account;


my $mock = mock_schema();

{
    $mock->seed_class
        ( 'R2::Schema::Country' =>
          { iso_code => 'us',
            name     => 'United States' },
          { iso_code => 'ca',
            name     => 'Canada' },
        );

    my $account =
        R2::Schema::Account->insert( name      => 'The Account',
                                     domain_id => 1,
                                   );

    for my $table ( qw( DonationSource DonationTarget PaymentType
                        AddressType PhoneNumberType MessagingProvider
                        AccountCountry ) )
    {
        my @actions =
            $mock->recorder()->actions_for_class( 'R2::Schema::' . $table );

        ok( scalar @actions,
            "found activity for $table table" );
        ok( ( all { $_->is_insert() } @actions ),
            'all the actions were inserts' );
    }
}
