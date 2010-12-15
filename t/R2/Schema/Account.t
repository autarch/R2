use strict;
use warnings;

use Test::More;

use lib 't/lib';
use R2::Test qw( mock_schema mock_dbh );

use List::MoreUtils qw( all );

use R2::Schema::Account;
use R2::Schema::Role;
use R2::Schema::User;

my $mock = mock_schema();
my $dbh  = mock_dbh();

my $account;

{
    $mock->seed_class(
        'R2::Schema::Country' => {
            iso_code => 'us',
            name     => 'United States'
        }, {
            iso_code => 'ca',
            name     => 'Canada'
        },
    );

    $account = R2::Schema::Account->insert(
        account_id => 1,
        name       => 'The Account',
        domain_id  => 1,
    );

    for my $table (
        qw( DonationSource DonationTarget PaymentType
        AddressType PhoneNumberType
        AccountCountry )
        ) {
        my @actions
            = $mock->recorder()->actions_for_class( 'R2::Schema::' . $table );

        ok(
            scalar @actions,
            "found activity for $table table"
        );
        ok(
            ( all { $_->is_insert() } @actions ),
            '. all the actions were inserts'
        );
    }
}

{
    my $user = R2::Schema::User->new(
        user_id     => 22,
        _from_query => 1,
    );
    my $role = R2::Schema::Role->Member();

    $account->add_user(
        user => $user,
        role => $role,
    );

    my ($insert)
        = $mock->recorder()->actions_for_class('R2::Schema::AccountUserRole');
    is_deeply(
        $insert->values(), {
            account_id => 1,
            user_id    => 22,
            role_id    => $role->role_id(),
        },
        'add_user inserts an AccountUserRole row'
    );
}

{
    $mock->recorder()->clear_all();

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [ [] ];

    $dbh->{mock_add_resultset} = [
        [qw( account_id donation_source_id name )],
        [ $account->account_id(), 1, 'mail' ],
        [ $account->account_id(), 2, 'online' ],
        [ $account->account_id(), 3, 'theft' ],
    ];

    $dbh->{mock_add_resultset} = [ [] ];

    $dbh->{mock_add_resultset} = [
        ['count'],
        [0],
    ];

    $account->update_or_add_donation_sources(
        {
            1 => { name => 'male' },
            3 => { name => 'theft' },
        },
        [ { name => 'lemonade stand' } ],
    );

    my @actions
        = $mock->recorder()->actions_for_class('R2::Schema::DonationSource');

    is(
        scalar @actions, 4,
        '4 actions for R2::Schema::DonationSource'
    );

    ok(
        $actions[0]->is_update(),
        '. first action for is an update'
    );
    is_deeply(
        $actions[0]->pk(),
        { donation_source_id => 1 },
        '.. updated donation_source_id == 1'
    );
    is_deeply(
        $actions[0]->values(),
        { name => 'male' },
        q{.. update set name = 'male'}
    );

    ok(
        $actions[1]->is_delete(),
        '. second action is a delete'
    );
    is_deeply(
        $actions[1]->pk(),
        { donation_source_id => 2 },
        '.. deleted donation_source_id == 2'
    );

    ok(
        $actions[2]->is_update(),
        '. third action for is an update'
    );
    is_deeply(
        $actions[2]->pk(),
        { donation_source_id => 3 },
        '.. updated donation_source_id == 3'
    );
    is_deeply(
        $actions[2]->values(),
        { name => 'theft' },
        q{.. update set name = 'theft'}
    );

    ok(
        $actions[3]->is_insert(),
        '. fourth action is an insert'
    );
    is_deeply(
        $actions[3]->values(), {
            account_id => $account->account_id(),
            name       => 'lemonade stand',
        },
        '.. inserted a new donation source'
    );
}

{
    $mock->recorder()->clear_all();

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [ [] ];

    $dbh->{mock_add_resultset} = [
        [qw( account_id donation_target_id name )],
        [ $account->account_id(), 1, 'General Fund' ],
        [ $account->account_id(), 2, 'Pants Program' ],
        [ $account->account_id(), 3, 'Unsavory Things' ],
    ];

    $dbh->{mock_add_resultset} = [ [] ];

    $dbh->{mock_add_resultset} = [
        ['count'],
        [0],
    ];

    $account->update_or_add_donation_targets(
        {
            1 => { name => 'Corporal Fund' },
            3 => { name => 'Unsavory Things' },
        },
        [ { name => 'Rehab' } ],
    );

    my @actions
        = $mock->recorder()->actions_for_class('R2::Schema::DonationTarget');

    is(
        scalar @actions, 4,
        '4 actions for R2::Schema::DonationTarget'
    );

    ok(
        $actions[0]->is_update(),
        '. first action for is an update'
    );
    is_deeply(
        $actions[0]->pk(),
        { donation_target_id => 1 },
        '.. updated donation_target_id == 1'
    );
    is_deeply(
        $actions[0]->values(),
        { name => 'Corporal Fund' },
        q{.. update set name = 'Corporal Fund'}
    );

    ok(
        $actions[1]->is_delete(),
        '. second action is a delete'
    );
    is_deeply(
        $actions[1]->pk(),
        { donation_target_id => 2 },
        '.. deleted donation_target_id == 2'
    );

    ok(
        $actions[2]->is_update(),
        '. third action for is an update'
    );
    is_deeply(
        $actions[2]->pk(),
        { donation_target_id => 3 },
        '.. updated donation_target_id == 3'
    );
    is_deeply(
        $actions[2]->values(),
        { name => 'Unsavory Things' },
        q{.. update set name = 'Unsavory Things'}
    );

    ok(
        $actions[3]->is_insert(),
        '. fourth action is an insert'
    );
    is_deeply(
        $actions[3]->values(), {
            account_id => $account->account_id(),
            name       => 'Rehab',
        },
        '.. inserted a new donation target'
    );
}

{
    $mock->recorder()->clear_all();

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [ [] ];

    $dbh->{mock_add_resultset} = [
        [qw( account_id name payment_type_id )],
        [ $account->account_id(), 'credit card', 1 ],
        [ $account->account_id(), 'cash',        2 ],
        [ $account->account_id(), 'check',       3 ],
    ];

    $dbh->{mock_add_resultset} = [ [] ];

    $dbh->{mock_add_resultset} = [
        ['count'],
        [0],
    ];

    $account->update_or_add_payment_types(
        {
            1 => { name => 'cowrie shells' },
            3 => { name => 'check' },
        },
        [ { name => 'ammo and fuel' } ],
    );

    my @actions
        = $mock->recorder()->actions_for_class('R2::Schema::PaymentType');

    is(
        scalar @actions, 4,
        '4 actions for R2::Schema::PaymentType'
    );

    ok(
        $actions[0]->is_update(),
        '. first action for is an update'
    );
    is_deeply(
        $actions[0]->pk(),
        { payment_type_id => 1 },
        '.. updated payment_type_id == 1'
    );
    is_deeply(
        $actions[0]->values(),
        { name => 'cowrie shells' },
        q{.. update set name = 'cowrie shells'}
    );

    ok(
        $actions[1]->is_delete(),
        '. second action is a delete'
    );
    is_deeply(
        $actions[1]->pk(),
        { payment_type_id => 2 },
        '.. deleted payment_type_id == 2'
    );

    ok(
        $actions[2]->is_update(),
        '. third action for is an update'
    );
    is_deeply(
        $actions[2]->pk(),
        { payment_type_id => 3 },
        '.. updated payment_type_id == 3'
    );
    is_deeply(
        $actions[2]->values(),
        { name => 'check' },
        q{.. update set name = 'check'}
    );

    ok(
        $actions[3]->is_insert(),
        '. fourth action is an insert'
    );
    is_deeply(
        $actions[3]->values(), {
            account_id => $account->account_id(),
            name       => 'ammo and fuel',
        },
        '.. inserted a new payment type'
    );
}

{
    $mock->recorder()->clear_all();

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [ [] ];

    $dbh->{mock_add_resultset} = [
        [
            qw( account_id address_type_id
                applies_to_household applies_to_organization
                applies_to_person name )
        ],
        [ $account->account_id(), 1, 1, 0, 1, 'Home' ],
        [ $account->account_id(), 2, 0, 1, 0, 'Headquarters' ],
        [ $account->account_id(), 3, 0, 0, 1, 'Work' ],
    ];

    for ( 1 .. 7 ) {
        $dbh->{mock_add_resultset} = [
            ['count'],
            [0],
        ];
    }

    $account->update_or_add_address_types(
        {
            1 => {
                name                    => 'Home and hearth',
                applies_to_household    => 0,
                applies_to_organization => 0,
                applies_to_person       => 1,
            },
            3 => {
                name                    => 'Work',
                applies_to_household    => 0,
                applies_to_organization => 0,
                applies_to_person       => 1,
            },
        },
        [
            {
                name                    => 'Vacation Home',
                applies_to_household    => 1,
                applies_to_organization => 0,
                applies_to_person       => 1,
            }
        ],
    );

    my @actions
        = $mock->recorder()->actions_for_class('R2::Schema::AddressType');

    is(
        scalar @actions, 4,
        '4 actions for R2::Schema::AddressType'
    );

    ok(
        $actions[0]->is_update(),
        '. first action for is an update'
    );
    is_deeply(
        $actions[0]->pk(),
        { address_type_id => 1 },
        '.. updated address_type_id == 1'
    );
    is_deeply(
        $actions[0]->values(), {
            name                    => 'Home and hearth',
            applies_to_household    => 0,
            applies_to_organization => 0,
            applies_to_person       => 1,
        },
        q{.. update set name = 'Home and hearth'}
    );

    ok(
        $actions[1]->is_delete(),
        '. second action is a delete'
    );
    is_deeply(
        $actions[1]->pk(),
        { address_type_id => 2 },
        '.. deleted address_type_id == 2'
    );

    ok(
        $actions[2]->is_update(),
        '. third action for is an update'
    );
    is_deeply(
        $actions[2]->pk(),
        { address_type_id => 3 },
        '.. updated address_type_id == 3'
    );
    is_deeply(
        $actions[2]->values(), {
            name                    => 'Work',
            applies_to_household    => 0,
            applies_to_organization => 0,
            applies_to_person       => 1,
        },
        q{.. update set name = 'Work'}
    );

    ok(
        $actions[3]->is_insert(),
        '. fourth action is an insert'
    );
    is_deeply(
        $actions[3]->values(), {
            account_id              => $account->account_id(),
            name                    => 'Vacation Home',
            applies_to_household    => 1,
            applies_to_organization => 0,
            applies_to_person       => 1,
        },
        '.. inserted a new address type'
    );
}

{
    $mock->recorder()->clear_all();

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [ [] ];

    $dbh->{mock_add_resultset} = [
        [
            qw( account_id
                applies_to_household applies_to_organization
                applies_to_person name
                phone_number_type_id )
        ],
        [ $account->account_id(), 1, 0, 1, 'Home',   1 ],
        [ $account->account_id(), 0, 1, 1, 'Office', 2 ],
        [ $account->account_id(), 0, 0, 1, 'Cell',   3 ],
    ];

    for ( 1 .. 7 ) {
        $dbh->{mock_add_resultset} = [
            ['count'],
            [0],
        ];
    }

    $account->update_or_add_phone_number_types(
        {
            1 => {
                name                    => 'House',
                applies_to_household    => 0,
                applies_to_organization => 0,
                applies_to_person       => 1,
            },
            3 => {
                name                    => 'Cell',
                applies_to_household    => 0,
                applies_to_organization => 0,
                applies_to_person       => 1,
            },
        },
        [
            {
                name                    => 'Secret Phone',
                applies_to_household    => 1,
                applies_to_organization => 1,
                applies_to_person       => 1,
            }
        ],
    );

    my @actions
        = $mock->recorder()->actions_for_class('R2::Schema::PhoneNumberType');

    is(
        scalar @actions, 4,
        '4 actions for R2::Schema::PhoneNumberType'
    );

    ok(
        $actions[0]->is_update(),
        '. first action for is an update'
    );
    is_deeply(
        $actions[0]->pk(),
        { phone_number_type_id => 1 },
        '.. updated phone_number_type_id == 1'
    );
    is_deeply(
        $actions[0]->values(), {
            name                    => 'House',
            applies_to_household    => 0,
            applies_to_organization => 0,
            applies_to_person       => 1,
        },
        q{.. update set name = 'House'}
    );

    ok(
        $actions[1]->is_delete(),
        '. second action is a delete'
    );
    is_deeply(
        $actions[1]->pk(),
        { phone_number_type_id => 2 },
        '.. deleted phone_number_type_id == 2'
    );

    ok(
        $actions[2]->is_update(),
        '. third action for is an update'
    );
    is_deeply(
        $actions[2]->pk(),
        { phone_number_type_id => 3 },
        '.. updated phone_number_type_id == 3'
    );
    is_deeply(
        $actions[2]->values(), {
            name                    => 'Cell',
            applies_to_household    => 0,
            applies_to_organization => 0,
            applies_to_person       => 1,
        },
        q{.. update set name = 'Cell'}
    );

    ok(
        $actions[3]->is_insert(),
        '. fourth action is an insert'
    );
    is_deeply(
        $actions[3]->values(), {
            account_id              => $account->account_id(),
            name                    => 'Secret Phone',
            applies_to_household    => 1,
            applies_to_organization => 1,
            applies_to_person       => 1,
        },
        '.. inserted a new phone number type'
    );
}

{
    $mock->recorder()->clear_all();

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [ [] ];

    $dbh->{mock_add_resultset} = [
        [qw( account_id contact_note_type_id description is_system_defined )],
        [ $account->account_id(), 1, 'Talked', 0 ],
        [ $account->account_id(), 2, 'Called', 0 ],
        [ $account->account_id(), 3, 'IM',     0 ],
    ];

    for ( 1 .. 2 ) {
        $dbh->{mock_add_resultset} = [
            ['count'],
            [0],
        ];
    }

    $account->update_or_add_contact_note_types(
        {
            1 => { description => 'Yakked' },
            3 => { description => 'IM' },
        },
        [
            {
                description       => 'Telegraphed',
                is_system_defined => 0,
            }
        ],
    );

    my @actions
        = $mock->recorder()->actions_for_class('R2::Schema::ContactNoteType');

    is(
        scalar @actions, 4,
        '4 actions for R2::Schema::ContactNoteType'
    );

    ok(
        $actions[0]->is_update(),
        '. first action for is an update'
    );
    is_deeply(
        $actions[0]->pk(),
        { contact_note_type_id => 1 },
        '.. updated contact_note_type_id == 1'
    );
    is_deeply(
        $actions[0]->values(),
        { description => 'Yakked' },
        q{.. update set description = 'Yakked'}
    );

    ok(
        $actions[1]->is_delete(),
        '. second action is a delete'
    );
    is_deeply(
        $actions[1]->pk(),
        { contact_note_type_id => 2 },
        '.. deleted contact_note_type_id == 2'
    );

    ok(
        $actions[2]->is_update(),
        '. third action for is an update'
    );
    is_deeply(
        $actions[2]->pk(),
        { contact_note_type_id => 3 },
        '.. updated contact_note_type_id == 3'
    );
    is_deeply(
        $actions[2]->values(),
        { description => 'IM' },
        q{.. update set description = 'IM'}
    );

    ok(
        $actions[3]->is_insert(),
        '. fourth action is an insert'
    );
    is_deeply(
        $actions[3]->values(), {
            account_id        => $account->account_id(),
            description       => 'Telegraphed',
            is_system_defined => 0,
        },
        '.. inserted a new contact note type'
    );
}

{
    $mock->recorder()->clear_all();

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [ [] ];

    $dbh->{mock_add_resultset} = [
        [qw( account_id donation_source_id name )],
    ];

    # this is a cached iterator so we want to avoid getting the old data
    $account->donation_sources()->_clear_cached_results();

    $account->update_or_add_donation_sources(
        {},
        [ { name => 'lemonade stand' } ],
    );

    my @actions
        = $mock->recorder()->actions_for_class('R2::Schema::DonationSource');

    is(
        scalar @actions, 1,
        '1 action for R2::Schema::DonationSource'
    );
    ok(
        $actions[0]->is_insert(),
        'can insert but not update via update_or_add_donation_sources'
    );
}

{
    $mock->recorder()->clear_all();

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [ [] ];

    $dbh->{mock_add_resultset} = [
        [qw( account_id donation_source_id name )],
        [ $account->account_id(), 1, 'mail' ],
    ];

    $account->donation_sources()->_clear_cached_results();
    $account->donation_sources()->reset();

    $account->update_or_add_donation_sources(
        {
            1 => { name => 'male' },
        },
    );

    my @actions
        = $mock->recorder()->actions_for_class('R2::Schema::DonationSource');

    is(
        scalar @actions, 1,
        '1 action for R2::Schema::DonationSource'
    );
    ok(
        $actions[0]->is_update(),
        'can update but not insert via update_or_add_donation_sources'
    );
}

{
    $mock->recorder()->clear_all();

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [ [] ];

    $dbh->{mock_add_resultset} = [
        [qw( account_id donation_source_id name )],
        [ $account->account_id(), 1, 'mail' ],
        [ $account->account_id(), 2, 'online' ],
    ];

    $dbh->{mock_add_resultset} = [ [] ];

    $dbh->{mock_add_resultset} = [
        ['count'],
        [10],
    ];

    $account->donation_sources()->_clear_cached_results();
    $account->donation_sources()->reset();

    $account->update_or_add_donation_sources(
        {
            1 => { name => 'male' },
        },
    );

    my @actions
        = $mock->recorder()->actions_for_class('R2::Schema::DonationSource');

    is(
        scalar @actions, 1,
        '1 action for R2::Schema::DonationSource (did not attempt to delete undeleteable source)'
    );
    ok(
        $actions[0]->is_update(),
        'can update but not insert via update_or_add_donation_sources'
    );
}

{
    eval { $account->update_or_add_donation_sources( {}, [] ) };

    like(
        $@, qr/\QYou must have at least one donation source./,
        'Cannot call update_or_add_donation_sources with nothing to update or add'
    );
}

{
    $mock->seed_class(
        'R2::Schema::ContactNoteType' => {
            account_id           => $account->account_id(),
            contact_note_type_id => 5,
        },
    );

    my $type = $account->_build_made_a_note_contact_note_type();

    is(
        $type->description(), 'Made a note',
        '_build_made_a_note_contact_note_type returns something sane'
    );
}

{
    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [
        [qw( account_id is_default iso_code iso_code name )],
        [ 1, 1, 'us', 'us', 'United States' ],
        [ 1, 0, 'ca', 'ca', 'Canada' ],
    ];

    my @countries = $account->_build_countries()->all();

    is(
        scalar @countries, 2,
        'found two countries for this account'
    );
}

{
    is(
        $account->_base_uri_path(), '/account/1',
        '_base_uri_path() is /account/1'
    );
}

done_testing();
