use strict;
use warnings;

use Test::More tests => 26;

use lib 't/lib';
use R2::Test qw( mock_schema mock_dbh );

use List::MoreUtils qw( all );

use R2::Schema::Account;
use R2::Schema::Role;
use R2::Schema::User;


my $mock = mock_schema();
my $dbh = mock_dbh();

my $account;

{
    $mock->seed_class
        ( 'R2::Schema::Country' =>
          { iso_code => 'us',
            name     => 'United States' },
          { iso_code => 'ca',
            name     => 'Canada' },
        );

    $account =
        R2::Schema::Account->insert( account_id => 1,
                                     name       => 'The Account',
                                     domain_id  => 1,
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
            '. all the actions were inserts' );
    }
}

{
    my $user = R2::Schema::User->new( user_id     => 22,
                                      _from_query => 1,
                                    );
    my $role = R2::Schema::Role->Member();

    $account->add_user( user => $user,
                        role => $role,
                      );

    my ($insert) = $mock->recorder()->actions_for_class('R2::Schema::AccountUserRole');
    is_deeply( $insert->values(),
               { account_id => 1,
                 user_id    => 22,
                 role_id    => $role->role_id(),
               },
               'add_user inserts an AccountUserRole row' );
}

{
    $mock->recorder()->clear_all();

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [[]];

    $dbh->{mock_add_resultset} =
        [ [ qw( account_id donation_source_id name ) ],
          [ 1, 1, 'mail' ],
          [ 1, 2, 'online' ],
          [ 1, 3, 'theft' ],
        ];

    $dbh->{mock_add_resultset} =
        [ [ 'count' ],
          [ 10 ],
        ];

    $dbh->{mock_add_resultset} =
        [ [ 'count' ],
          [ 0 ],
        ];

    $account->update_or_add_donation_sources
        ( { 1 => { name => 'male' },
            3 => { name => 'theft' },
          },
          [ { name => 'lemonade stand' } ],
        );

    my @actions = $mock->recorder()->actions_for_class('R2::Schema::DonationSource');

    is( scalar @actions, 4,
        '3 actions for R2::Schema::DonationSource' );

    ok( $actions[0]->is_update(),
        '. first action for is an update' );
    is_deeply( $actions[0]->pk(),
               { donation_source_id => 1 },
               '.. updated donation_source_id == 1' );
    is_deeply( $actions[0]->values(),
               { name => 'male' },
               q{.. update set name = 'make'} );

    ok( $actions[1]->is_delete(),
        '. second action is a delete' );
    is_deeply( $actions[1]->pk(),
               { donation_source_id => 2 },
               '.. deleted donation_source_id == 2' );

    ok( $actions[2]->is_update(),
        '. third action for is an update' );
    is_deeply( $actions[2]->pk(),
               { donation_source_id => 3 },
               '.. updated donation_source_id == 3' );
    is_deeply( $actions[2]->values(),
               { name => 'theft' },
               q{.. update set name = 'theft'} );

    ok( $actions[3]->is_insert(),
        '. fourth action is an insert' );
    is_deeply( $actions[3]->values(),
               { account_id => $account->account_id(),
                 name       => 'lemonade stand',
               },
               '.. inserted a new donation source' );
}
