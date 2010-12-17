use strict;
use warnings;

use Test::More;

use lib 't/lib';
use R2::Test::RealSchema;

use R2::Schema::Account;
use R2::Schema::Contact;

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
)->contact();

{
    my $target       = $account->donation_targets()->next();
    my $source       = $account->donation_sources()->next();
    my $payment_type = $account->payment_types()->next();

    $contact->add_donation(
        donation_target_id => $target->donation_target_id(),
        donation_source_id => $source->donation_source_id(),
        payment_type_id    => $payment_type->payment_type_id(),
        amount             => 42,
        donation_date      => '2008-01-01',
    );

    is(
        $contact->donation_count(),
        1,
        'add_donation added a donation'
    );
}

{
    $contact->add_email_address( email_address => 'dave@example.com' );

    is(
        $contact->email_address_count(),
        1,
        'add_email_address added an email address'
    );

    is(
        $contact->preferred_email_address()->email_address(),
        'dave@example.com',
        'adding an email address makes the address preferred when the contact has no other addresses'
    );
}

{
    $contact->add_website( uri => 'http://example.com' );

    is(
        $contact->website_count(),
        1,
        'add_website added a website'
    );
}

{
    my $address_type = $account->address_types()->next();

    $contact->add_address(
        address_type_id => $address_type->address_type_id(),
        street_1        => '99 Some Drive',
        city            => 'Minneapolis',
        region          => 'MN',
        iso_code        => 'us',
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

    $contact->add_phone_number(
        phone_number_type_id => $phone_number_type->phone_number_type_id(),
        phone_number         => '612-555-1123',
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
    my $target       = $account->donation_targets()->next();
    my $source       = $account->donation_sources()->next();
    my $payment_type = $account->payment_types()->next();

    $contact->add_donation(
        donation_target_id => $target->donation_target_id(),
        donation_source_id => $source->donation_source_id(),
        payment_type_id    => $payment_type->payment_type_id(),
        amount             => 500,
        donation_date      => '2009-01-01',
    );

    $contact->add_donation(
        donation_target_id => $target->donation_target_id(),
        donation_source_id => $source->donation_source_id(),
        payment_type_id    => $payment_type->payment_type_id(),
        amount             => 501,
        donation_date      => '2010-01-01',
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

done_testing();
