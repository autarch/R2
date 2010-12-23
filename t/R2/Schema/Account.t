use strict;
use warnings;

use Test::Exception;
use Test::More;

use lib 't/lib';

use List::MoreUtils qw( all );
use R2::Test::RealSchema;

use R2::Schema::Account;
use R2::Schema::Domain;
use R2::Schema::Role;
use R2::Schema::User;

my $user   = R2::Schema::User->SystemUser();
my $domain = R2::Schema::Domain->DefaultDomain();

my $account;

{
    $account = R2::Schema::Account->insert(
        name       => 'The Account',
        domain_id  => $domain->domain_id(),
    );

    for my $meth (
        qw(
        donation_sources donation_campaigns payment_types
        address_types phone_number_types
        messaging_providers
        contact_note_types
        countries )
        ) {

        my @objects = $account->$meth()->all();
        ok(
            scalar @objects,
            "after inserting an account the $meth method finds related rows"
        );
    }
}

{
    $account->add_country(
        country => R2::Schema::Country->new(
            iso_code => $_,
        ),
        is_default => 0,
    ) for 'gu', 'gb';

    is_deeply(
        [ map { $_->name() } $account->countries()->all() ],
        [ 'United States', 'Canada', 'Guam', 'United Kingdom' ],
        'countries returns default country first, then ordered by name'
    );
}

{
    my $bob = R2::Schema::User->insert(
        first_name    => 'Bob',
        email_address => 'bob@example.com',
        password      => 'foo',
        account_id    => $account->account_id(),
        user          => $user,
    );

    $account->add_user(
        user => $bob,
        role => R2::Schema::Role->Member(),
    );

    is_deeply(
        users_with_roles_data($account),
        [ [ 'bob@example.com', 'Member' ] ],
        'got expected users after calling add_users'
    );

    my $lisa = R2::Schema::User->insert(
        first_name    => 'Lisa',
        email_address => 'lisa@example.com',
        password      => 'foo',
        account_id    => $account->account_id(),
        user          => $user,
    );

    my $role = R2::Schema::Role->Member();

    $account->add_user(
        user => $lisa,
        role => R2::Schema::Role->Admin(),
    );

    is_deeply(
        users_with_roles_data($account),
        [
            [ 'bob@example.com',  'Member' ],
            [ 'lisa@example.com', 'Admin' ],
        ],
        'got expected users after calling add_users'
    );
}

{
    my %sources
        = map { $_->name() => $_ } $account->donation_sources()->all();

    $account->update_or_add_donation_sources(
        {
            $sources{mail}->donation_source_id()   => { name => 'male' },
            $sources{online}->donation_source_id() => { name => 'theft' },
        },
        [
            { name => 'lemonade stand' },
            { name => 'bake sale' },
        ],
    );

    is_deeply(
        [ map { $_->name() } $account->donation_sources()->all() ],
        [ 'bake sale', 'lemonade stand', 'male', 'theft' ],
        'got expected donation sources after update_or_add_donation_sources'
    );
}

{
    my %campaigns
        = map { $_->name() => $_ } $account->donation_campaigns()->all();

    $account->update_or_add_donation_campaigns(
        {
            $campaigns{'General Fund'}->donation_campaign_id() =>
                { name => 'Pyramid Scheme' },
        },
        [
            { name => 'Tofu Party Fund' },
            { name => 'World Domination Fund' },
        ],
    );

    is_deeply(
        [ map { $_->name() } $account->donation_campaigns()->all() ],
        [ 'Pyramid Scheme', 'Tofu Party Fund', 'World Domination Fund' ],
        'got expected donation campaigns after update_or_add_donation_campaigns'
    );
}

{
    my %types = map { $_->name() => $_ } $account->payment_types()->all();

    $account->update_or_add_payment_types(
        {
            $types{cash}->payment_type_id() => { name => 'cowrie shells' },
            $types{check}->payment_type_id() =>
                { name => 'archaic paper' },
        },
        [
            { name => 'cookies' },
            { name => 'favors' },
        ],
    );

    is_deeply(
        [ map { $_->name() } $account->payment_types()->all() ],
        [ 'archaic paper', 'cookies', 'cowrie shells', 'favors' ],
        'got expected payment types after update_or_add_payment_types'
    );
}

{
    my %types = map { $_->name() => $_ } $account->address_types()->all();

    $account->update_or_add_address_types(
        {
            $types{Home}->address_type_id() => {
                name                    => 'Home and hearth',
                applies_to_household    => 0,
                applies_to_organization => 0,
                applies_to_person       => 1,
            },
            $types{Work}->address_type_id() => {
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

    is_deeply(
        [
            map {
                {
                    name                    => $_->name(),
                    applies_to_household    => $_->applies_to_household(),
                    applies_to_organization => $_->applies_to_organization(),
                    applies_to_person       => $_->applies_to_person(),
                }
                } $account->address_types()->all()
        ],
        [
            {
                name                    => 'Home and hearth',
                applies_to_household    => 0,
                applies_to_organization => 0,
                applies_to_person       => 1,
            }, {
                name                    => 'Vacation Home',
                applies_to_household    => 1,
                applies_to_organization => 0,
                applies_to_person       => 1,
            }, {
                name                    => 'Work',
                applies_to_household    => 0,
                applies_to_organization => 0,
                applies_to_person       => 1,
            },
        ],
        'got expected address types after update_or_add_address_types'
    );
}

{
    my %types
        = map { $_->name() => $_ } $account->phone_number_types()->all();

    $account->update_or_add_phone_number_types(
        {
            $types{Home}->phone_number_type_id() => {
                name                    => 'House',
                applies_to_household    => 0,
                applies_to_organization => 0,
                applies_to_person       => 1,
            },
            $types{Office}->phone_number_type_id() => {
                name                    => 'Work',
                applies_to_household    => 0,
                applies_to_organization => 1,
                applies_to_person       => 1,
            },
        },
        [
            {
                name                    => 'Brain',
                applies_to_household    => 1,
                applies_to_organization => 0,
                applies_to_person       => 1,
            }
        ],
    );

    is_deeply(
        [
            map {
                {
                    name                    => $_->name(),
                    applies_to_household    => $_->applies_to_household(),
                    applies_to_organization => $_->applies_to_organization(),
                    applies_to_person       => $_->applies_to_person(),
                }
                } $account->phone_number_types()->all()
        ],
        [
            {
                name                    => 'Brain',
                applies_to_household    => 1,
                applies_to_organization => 0,
                applies_to_person       => 1,
            }, {
                name                    => 'House',
                applies_to_household    => 0,
                applies_to_organization => 0,
                applies_to_person       => 1,
            }, {
                name                    => 'Work',
                applies_to_household    => 0,
                applies_to_organization => 1,
                applies_to_person       => 1,
            },
        ],
        'got expected phone number types after update_or_add_phone_number_types'
    );
}

{
    my %types
        = map { $_->description() => $_ } $account->contact_note_types()->all();

    $account->update_or_add_contact_note_types(
        {
            $types{'Called this contact'}->contact_note_type_id() => {
                description => 'Dialed the telephone',
            },
            $types{'Met with this contact'}->contact_note_type_id() => {
                description => 'In the flesh encounter',
            },
        },
        [
            {
                description       => 'Dreamed of this contact',
                is_system_defined => 0,
            }
        ],
    );

    is_deeply(
        [
            map {
                {
                    description       => $_->description(),
                    is_system_defined => $_->is_system_defined(),
                }
                } $account->contact_note_types()->all()
        ],
        [
            {
                description       => 'Made a note',
                is_system_defined => 1,
            }, {
                description       => 'Dialed the telephone',
                is_system_defined => 0,
            }, {
                description       => 'Dreamed of this contact',
                is_system_defined => 0,
            }, {
                description       => 'In the flesh encounter',
                is_system_defined => 0,
            },
        ],
        'got expected contact note types after update_or_add_contact_note_types'
    );
}

{
    is(
        $account->made_a_note_contact_note_type()->description(),
        'Made a note',
        'made_a_note_contact_note_type() returns the right contact note type'
    );
}

{
    throws_ok { $account->update_or_add_donation_sources( {}, [] ) }
    qr/\QYou must have at least one donation source./,
        'Cannot call update_or_add_donation_sources with nothing to update or add';
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

    is(
        $account->custom_field_group_count(),
        3,
        'account has three custom field groups after update_or_add_custom_field_groups'
    );

    is_deeply(
        [
            map { $_->name() }
                $account->custom_field_groups_for_person()->all()
        ],
        [ 'Group 1', 'Group 3' ],
        'custom_field_groups_for_person'
    );

    is_deeply(
        [
            map { $_->name() }
                $account->custom_field_groups_for_household()->all()
        ],
        [ 'Group 2', 'Group 3' ],
        'custom_field_groups_for_household'
    );

    is_deeply(
        [
            map { $_->name() }
                $account->custom_field_groups_for_organization()->all()
        ],
        [ 'Group 1', 'Group 2' ],
        'custom_field_groups_for_organization'
    );
}

sub users_with_roles_data {
    my $account = shift;

    my $uwr = $account->users_with_roles();

    my @users;
    while ( my ( $user, $role ) = $uwr->next() ) {
        push @users, [ $user->username(), $role->name() ];
    }

    return \@users;
}

done_testing();
