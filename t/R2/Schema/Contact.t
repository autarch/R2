use strict;
use warnings;

use Test::More;

use lib 't/lib';
use R2::Test::RealSchema;

use R2::Schema::Account;
use R2::Schema::Contact;
use R2::Schema::User;

my $account = R2::Schema::Account->new( name => q{Judean People's Front} );

{
    for my $type (qw( Person Organization Household )) {
        my %name
            = $type eq 'Person'
            ? ( first_name => 'Bob' )
            : ( name => 'Whatever' );

        my $real_class = 'R2::Schema::' . $type;
        my $id_col     = lc $type . '_id';

        my $contact = $real_class->insert(
            %name,
            account_id => $account->account_id(),
            user       => R2::Schema::User->SystemUser(),
        )->contact();

        my $real = $contact->real_contact();
        isa_ok(
            $real,
            $real_class,
            'real_contact returns expected type of object'
        );
    }
}

my $contact = R2::Schema::Person->insert(
    account_id => $account->account_id(),
    first_name => 'Jane',
    user       => R2::Schema::User->SystemUser(),
)->contact();

{
    my $campaign     = $account->donation_campaigns()->next();
    my $source       = $account->donation_sources()->next();
    my $payment_type = $account->payment_types()->next();

    $contact->add_donation(
        donation_campaign_id => $campaign->donation_campaign_id(),
        donation_source_id   => $source->donation_source_id(),
        payment_type_id      => $payment_type->payment_type_id(),
        amount               => 42,
        donation_date        => '2008-01-01',
        user                 => R2::Schema::User->SystemUser(),
    );

    is(
        $contact->donation_count(),
        1,
        'add_donation added a donation'
    );
}

{
    $contact->update_or_add_email_addresses(
        {},
        [
            { email_address => 'dave@example.com' },
        ],
        R2::Schema::User->SystemUser(),
    );

    is(
        $contact->email_address_count(),
        1,
        'add_or_update_email_address added an email address'
    );

    is(
        $contact->preferred_email_address()->email_address(),
        'dave@example.com',
        'adding an email address makes the address preferred when the contact has no other addresses'
    );

    my $email = $contact->preferred_email_address();

    $contact->update_or_add_email_addresses(
        {
            $email->email_address_id() => {
                email_address => 'bob@example.com',
            },
        },
        [
            { email_address => 'foo@example.com' },
        ],
        R2::Schema::User->SystemUser(),
    );

    is(
        $contact->email_address_count(),
        2,
        'add_or_update_email_address added an email address'
    );

    is(
        $contact->preferred_email_address()->email_address(),
        'bob@example.com',
        'preferred email address was changed'
    );

    my $non_preferred = ( $contact->email_addresses()->all() )[1];

    $contact->update_or_add_email_addresses(
        {
            $non_preferred->email_address_id() => {
                email_address => 'foo@example.com',
                is_preferred  => 1,
            },
        },
        [],
        R2::Schema::User->SystemUser(),
    );

    is(
        $contact->email_address_count(),
        1,
        'add_or_update_email_address deleted an email address not included in the list of existing addresses'
    );


    is(
        $contact->preferred_email_address()->email_address(),
        'foo@example.com',
        'remaining email address is now preferred'
    );
}

{
    $contact->update_or_add_websites(
        {},
        [
            { uri => 'http://example.com' }
        ],
        R2::Schema::User->SystemUser(),
    );

    is(
        $contact->website_count(),
        1,
        'add_website added a website'
    );
}

{
    my $address_type = $account->address_types()->next();

    $contact->update_or_add_addresses(
        {},
        [
            {
                address_type_id => $address_type->address_type_id(),
                street_1        => '99 Some Drive',
                city            => 'Minneapolis',
                region          => 'MN',
            },
        ],
        R2::Schema::User->SystemUser(),
    );

    is(
        $contact->address_count(),
        1,
        'add_address added an address'
    );

    is(
        $contact->preferred_address()->street_1(),
        '99 Some Drive',
        'adding an address makes the address preferred when the contact has no other addresses'
    );
}

{
    my $phone_number_type = $account->phone_number_types()->next();

    $contact->update_or_add_phone_numbers(
        {},
        [
            {
                phone_number_type_id =>
                    $phone_number_type->phone_number_type_id(),
                phone_number => '612-555-1123',
            },
        ],
        R2::Schema::User->SystemUser(),
    );

    is(
        $contact->phone_number_count(),
        1,
        'add_phone_number added a phone number'
    );

    is(
        $contact->preferred_phone_number()->phone_number(),
        '612-555-1123',
        'adding a phone number makes the number preferred when the contact has no other numbers'
    );
}

{
    my $contact_note_type = $account->contact_note_types()->next();
    my $user              = ( $account->users_with_roles()->next() )[0];

    $contact->add_note(
        contact_note_type_id => $contact_note_type->contact_note_type_id(),
        note                 => 'blah blah',
        user_id              => $user->user_id(),
    );

    is(
        $contact->note_count(),
        1,
        'add_contact_note added a note'
    );
}

{
    my $campaign     = $account->donation_campaigns()->next();
    my $source       = $account->donation_sources()->next();
    my $payment_type = $account->payment_types()->next();

    $contact->add_donation(
        donation_campaign_id => $campaign->donation_campaign_id(),
        donation_source_id   => $source->donation_source_id(),
        payment_type_id      => $payment_type->payment_type_id(),
        amount               => 500,
        donation_date        => '2009-01-01',
        user                 => R2::Schema::User->SystemUser(),
    );

    $contact->add_donation(
        donation_campaign_id => $campaign->donation_campaign_id(),
        donation_source_id   => $source->donation_source_id(),
        payment_type_id      => $payment_type->payment_type_id(),
        amount               => 501,
        donation_date        => '2010-01-01',
        user                 => R2::Schema::User->SystemUser(),
    );

    is(
        $contact->donation_total(),
        1043,
        'donation total for all time is 1043',
    );

    my $y2009 = DateTime->new( year => 2009 );
    is(
        $contact->donation_total( since => $y2009 ),
        1001,
        'donation total since 2009 is 1001'
    );
}

{
    $account->update_or_add_custom_field_groups(
        {},
        [
            {
                name                    => 'Group 1',
                applies_to_person       => 1,
                applies_to_household    => 0,
                applies_to_organization => 1,
            }, {
                name                    => 'Group 2',
                applies_to_person       => 0,
                applies_to_household    => 1,
                applies_to_organization => 1,
            }, {
                name                    => 'Group 3',
                applies_to_person       => 1,
                applies_to_household    => 1,
                applies_to_organization => 0,
            },
        ],
    );

    my @groups = $account->custom_field_groups()->all();

    $groups[0]->update_or_add_custom_fields(
        {},
        [
            {
                label       => 'Field 1-1',
                description => 'custom field 1-1',
                type        => 'Integer',
            }, {
                label       => 'Field 1-2',
                description => 'custom field 1-2',
                type        => 'Decimal',
            },
        ]
    );

    $groups[1]->update_or_add_custom_fields(
        {},
        [
            {
                label       => 'Field 2-1',
                description => 'custom field 2-1',
                type        => 'Date',
            }, {
                label       => 'Field 2-2',
                description => 'custom field 2-2',
                type        => 'DateTime',
            }, {
                label       => 'Field 2-3',
                description => 'custom field 2-3',
                type        => 'Text',
            },
        ]
    );

    $groups[2]->update_or_add_custom_fields(
        {},
        [
            {
                label       => 'Field 3-1',
                description => 'custom field 3-1',
                type        => 'File',
            }, {
                label       => 'Field 3-2',
                description => 'custom field 3-2',
                type        => 'SingleSelect',
            }, {
                label       => 'Field 3-3',
                description => 'custom field 3-3',
                type        => 'MultiSelect',
            },
        ]
    );

    ok(
        !$contact->has_custom_field_values_for_group($_),
        'contact has no custom field values for group - ' . $_->name()
    ) for @groups;

    $contact->_clear_custom_field_values();

    my @fields1 = $groups[0]->custom_fields()->all();
    $fields1[0]->set_value_for_contact(
        contact => $contact,
        value   => 42,
    );

    ok(
        $contact->has_custom_field_values_for_group( $groups[0] ),
        'contact has a custom field value for Group 1'
    );
}

{
    my $contact = R2::Schema::Person->insert(
        account_id => $account->account_id(),
        first_name => 'Jane',
        user       => R2::Schema::User->SystemUser(),
    )->contact();

    my @history = $contact->history()->all();

    is(
        scalar @history, 1,
        'contact has one history entry',
    );

    is(
        $history[0]->type_name(),
        'Created',
        'history is a Created entry',
    );

    is(
        $history[0]->user_id(),
        R2::Schema::User->SystemUser()->user_id(),
        'user_id for history belongs to R2 System User'
    );

    $contact->update_or_add_email_addresses(
        {},
        [
            { email_address => 'foo@example.com' }
        ],
        R2::Schema::User->SystemUser(),
    );

    my $email = $contact->email_addresses()->next();

    $email->update(
        email_address => 'bar@example.com',
        user          => R2::Schema::User->SystemUser(),
    );

    $email->delete( user => R2::Schema::User->SystemUser() );

    my @history = $contact->history()->all();

    is(
        scalar @history, 4,
        'contact has four history entries',
    );
}

done_testing();
