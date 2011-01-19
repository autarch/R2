use strict;
use warnings;

use Test::More;

use lib 't/lib';

use R2::Test::RealSchema;

use R2::Schema::Account;
use R2::Schema::Donation;
use R2::Schema::Person;

my $account = R2::Schema::Account->new( name => q{Judean People's Front} );

my $contact = R2::Schema::Person->insert(
    account_id => $account->account_id(),
    first_name => 'Jane',
    user       => R2::Schema::User->SystemUser(),
)->contact();

my $campaign     = $account->donation_campaigns()->next();
my $source       = $account->donation_sources()->next();
my $payment_type = $account->payment_types()->next();

{
    eval {
        $contact->add_donation(
            donation_campaign_id => $campaign->donation_campaign_id(),
            donation_source_id   => $source->donation_source_id(),
            payment_type_id      => $payment_type->payment_type_id(),
            amount               => -2,
            donation_date        => '2008-01-01',
            user                 => R2::Schema::User->SystemUser(),
        );
    };

    my $e = $@;
    ok(
        $e,
        'got an exception with a donation amount of -2'
    );
    like(
        $e->full_message(),
        qr/The amount for a donation cannot be negative./,
        'got the expected error for a negative donation'
    );
}

{
    eval {
        $contact->add_donation(
            donation_campaign_id => $campaign->donation_campaign_id(),
            donation_source_id   => $source->donation_source_id(),
            payment_type_id      => $payment_type->payment_type_id(),
            amount               => 'qx2',
            donation_date        => '2008-01-01',
            user                 => R2::Schema::User->SystemUser(),
        );
    };

    my $e = $@;
    ok(
        $e,
        q{got an exception with a donation amount of "qx2"}
    );
    like(
        $e->full_message(),
        qr/\QThe amount you specified (qx2) does not seem to be a number./,
        'got the expected error for a non-numeric donation'
    );
}

{
    eval {
        $contact->add_donation(
            donation_campaign_id => $campaign->donation_campaign_id(),
            donation_source_id   => $source->donation_source_id(),
            payment_type_id      => $payment_type->payment_type_id(),
            amount               => '12.434',
            donation_date        => '2008-01-01',
            user                 => R2::Schema::User->SystemUser(),
        );
    };

    my $e = $@;
    ok(
        $e,
        'got an exception with a donation amount of 12.434'
    );
    like(
        $e->full_message(),
        qr/\QYou cannot have more than two digits to the right of the decimal point./,
        'got the expected error for a donation with three decimal places'
    );
}

{
    my $donation;

    eval {
        $donation = $contact->add_donation(
            donation_campaign_id => $campaign->donation_campaign_id(),
            donation_source_id   => $source->donation_source_id(),
            payment_type_id      => $payment_type->payment_type_id(),
            amount               => '$1,234.12',
            donation_date        => '2008-01-01',
            user                 => R2::Schema::User->SystemUser(),
        );
    };

    is(
        $donation->amount(),
        1234.12,
        'currency symbol and commas are stripped from donation'
    );

    is(
        $donation->formatted_amount(),
        '1,234.12',
        'formatted_amount() returns amount with commas for formatting'
    );

    is(
        $donation->summary(),
        '1,234.12 from Jane',
        'summary returns expected value'
    );
}

{
    eval {
        $contact->add_donation(
            donation_campaign_id => $campaign->donation_campaign_id(),
            donation_source_id   => $source->donation_source_id(),
            payment_type_id      => $payment_type->payment_type_id(),
            amount               => 12,
            donation_date        => 'foobar',
            user                 => R2::Schema::User->SystemUser(),
        );
    };

    my $e = $@;
    ok(
        $e,
        'got an exception with a donation date of 0'
    );
    like(
        $e->full_message(),
        qr/\QThis does not seem to be a valid date./,
        'got the expected error for a donation with an invalid date'
    );
}

done_testing();
