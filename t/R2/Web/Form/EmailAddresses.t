use strict;
use warnings;

use Test::More;

use lib 't/lib';

use R2::Test::RealSchema;

use R2::Schema::EmailAddress;
use R2::Schema::Person;
use R2::Schema::User;
use R2::Web::Form::EmailAddresses;

my $user    = R2::Schema::User->SystemUser();
my $account = R2::Schema::Account->new( name => q{Judean People's Front} );
my $form    = R2::Web::Form::EmailAddresses->new( user => $user );

my $person = R2::Schema::Person->insert(
    first_name => 'Bob',
    user       => $user,
    account_id => $account->account_id(),
);

my $email1 = R2::Schema::EmailAddress->insert(
    email_address => 'bob1@example.com',
    is_preferred  => 1,
    contact_id    => $person->contact_id(),
    user          => $user,
);

my $email2 = R2::Schema::EmailAddress->insert(
    email_address => 'bob2@example.com',
    is_preferred  => 0,
    contact_id    => $person->contact_id(),
    user          => $user,
);

{
    my $id = $email1->email_address_id();

    my $prefix = 'email_address.' . $id;

    my $new_address = 'bobX@example.com';
    my $note        = 'some words about this address';

    my $resultset = $form->process(
        params => {
            email_address_id           => [$id],
            "$prefix.email_address"    => $new_address,
            "$prefix.note"             => $note,
            email_address_is_preferred => $id,
        }
    );

    ok( $resultset->is_valid(), 'results are valid' );

    my $params = $resultset->results_as_hash();

    is_deeply(
        $params, {
            email_address_id => [$id],
            email_address    => {
                $id => {
                    email_address => $new_address,
                    note          => $note,
                },
            },
            email_address_is_preferred => $id,
            allows_email               => 1,
        },
        'got expected results back'
    );
}

{
    my $id1 = $email1->email_address_id();
    my $id2 = $email2->email_address_id();

    my $prefix1 = 'email_address.' . $id1;
    my $prefix2 = 'email_address.' . $id2;

    my $new_address1 = 'bobY@example.com';
    my $new_address2 = 'bobZ@example.com';
    my $note2        = 'blah blah';

    my $resultset = $form->process(
        params => {
            email_address_id           => [ $id1, $id2 ],
            "$prefix1.email_address"   => $new_address1,
            "$prefix2.email_address"   => $new_address2,
            "$prefix2.note"            => $note2,
            email_address_is_preferred => $id2,
        }
    );

    ok( $resultset->is_valid(), 'results are valid' );

    my $params = $resultset->results_as_hash();

    is_deeply(
        $params, {
            email_address_id => [ $id1, $id2 ],
            email_address    => {
                $id1 => {
                    email_address => $new_address1,
                },
                $id2 => {
                    email_address => $new_address2,
                    note          => $note2,
                },
            },
            email_address_is_preferred => $id2,
            allows_email               => 1,
        },
        'got expected results back'
    );
}

{
    my $id1 = $email1->email_address_id();
    my $id2 = $email2->email_address_id();

    my $prefix1 = 'email_address.' . $id1;
    my $prefix2 = 'email_address.' . $id2;

    my $new_address1 = 'bobY@example.com';
    my $new_address2 = 'bobZ@example.com';
    my $note2        = 'blah blah';

    my $resultset = $form->process(
        params => {
            email_address_id           => [ $id1, $id2 ],
            "$prefix1.email_address"   => $new_address1,
            "$prefix2.email_address"   => q{},
            email_address_is_preferred => $id1,
        }
    );

    ok( $resultset->is_valid(), 'results are valid' );

    my $params = $resultset->results_as_hash();

    is_deeply(
        $params, {
            email_address_id => [ $id1 ],
            email_address    => {
                $id1 => {
                    email_address => $new_address1,
                },
            },
            email_address_is_preferred => $id1,
            allows_email               => 1,
        },
        'got expected results back (empty address id is not included)'
    );
}

{
    my $id1 = $email1->email_address_id();
    my $id2 = $email2->email_address_id();

    my $prefix1 = 'email_address.' . $id1;
    my $prefix2 = 'email_address.' . $id2;

    my $address1 = $email1->email_address();
    my $address2 = $email2->email_address();
    my $note1    = $email1->note();
    my $note2    = $email2->note();

    my $resultset = $form->process(
        params => {
            email_address_id         => [ $id1, $id2, 'new1' ],
            "$prefix1.email_address" => $address1,
            "$prefix2.note"          => $note1,
            "$prefix2.email_address" => $address2,
            "$prefix2.note"          => $note2,
            'email_address.new1.email_address' => 'new@example.com',
            email_address_is_preferred         => 'new1',
        }
    );

    ok( $resultset->is_valid(), 'results are valid' );

    my $params = $resultset->results_as_hash();
    is_deeply(
        $params, {
            email_address_id => [ $id1, $id2, 'new1' ],
            email_address    => {
                $id1 => {
                    email_address => $address1,
                },
                $id2 => {
                    email_address => $address2,
                },
                new1 => {
                    email_address => 'new@example.com',
                },
            },
            email_address_is_preferred => 'new1',
            allows_email               => 1,
        },
        'got expected results back'
    );
}

{
    my $id = $email1->email_address_id();

    my $prefix = 'email_address.' . $id;

    my $new_address = 'bobX@example.';

    my $resultset = $form->process(
        params => {
            email_address_id           => [$id],
            "$prefix.email_address"    => $new_address,
            email_address_is_preferred => $id,
        }
    );

    ok(
        !$resultset->is_valid(),
        'results are not valid with bad email address'
    );

    is_deeply(
        _error_breakdown( { $resultset->field_errors() } ), {
            "$prefix.email_address" => [
                [
                    'invalid',
                    q{"bobX@example." is not a valid email address.}
                ]
            ],
        },
        'one field error for bad email address',
    );
}

{
    my $id1 = $email1->email_address_id();
    my $id2 = $email2->email_address_id();

    my $prefix1 = 'email_address.' . $id1;
    my $prefix2 = 'email_address.' . $id2;

    my $new_address1 = 'bobY@example.com';
    my $new_address2 = 'bobZ@example.';

    my $resultset = $form->process(
        params => {
            email_address_id           => [ $id1, $id2 ],
            "$prefix1.email_address"   => $new_address1,
            "$prefix2.email_address"   => $new_address2,
            email_address_is_preferred => $id2,
        }
    );

    ok(
        !$resultset->is_valid(),
        'results are not valid with bad email address'
    );

    is_deeply(
        _error_breakdown( { $resultset->field_errors() } ), {
            "$prefix2.email_address" => [
                [
                    'invalid',
                    q{"bobZ@example." is not a valid email address.}
                ]
            ],
        },
        'one field error for bad email address',
    );
}

{
    my $id1 = $email1->email_address_id();
    my $id2 = $email2->email_address_id();

    my $prefix1 = 'email_address.' . $id1;
    my $prefix2 = 'email_address.' . $id2;

    my $new_address1 = 'bobY@example.';
    my $new_address2 = 'bobZ@example.';

    my $resultset = $form->process(
        params => {
            email_address_id           => [ $id1, $id2 ],
            "$prefix1.email_address"   => $new_address1,
            "$prefix2.email_address"   => $new_address2,
            email_address_is_preferred => $id2,
        }
    );

    ok(
        !$resultset->is_valid(),
        'results are not valid with two bad email addresses'
    );

    is_deeply(
        _error_breakdown( { $resultset->field_errors() } ), {
            "$prefix1.email_address" => [
                [
                    'invalid',
                    q{"bobY@example." is not a valid email address.}
                ]
            ],
            "$prefix2.email_address" => [
                [
                    'invalid',
                    q{"bobZ@example." is not a valid email address.}
                ]
            ],
        },
        'two field errors for two bad email addresses',
    );
}

{
    my $id1 = $email1->email_address_id();
    my $id2 = $email2->email_address_id();

    my $prefix1 = 'email_address.' . $id1;
    my $prefix2 = 'email_address.' . $id2;

    my $address1 = 'just bad';
    my $address2 = $email2->email_address();

    my $resultset = $form->process(
        params => {
            email_address_id         => [ $id1, $id2, 'new1' ],
            "$prefix1.email_address" => $address1,
            "$prefix2.email_address" => $address2,
            'email_address.new1.email_address' => 'new@example.',
            email_address_is_preferred         => 'new1',
        }
    );

    ok(
        !$resultset->is_valid(),
        'results are not valid with two bad email addresses'
    );

    is_deeply(
        _error_breakdown( { $resultset->field_errors() } ), {
            "$prefix1.email_address" => [
                [
                    'invalid',
                    q{"just bad" is not a valid email address.}
                ]
            ],
            "email_address.new1.email_address" => [
                [
                    'invalid',
                    q{"new@example." is not a valid email address.}
                ]
            ],
        },
        'two field errors for two bad email addresses',
    );
}

{
    my $resultset = $form->process(
        params => {
            email_address_id                   => ['new1'],
            "email_address.new1.email_address" => q{},
            "email_address.new1.note"          => q{},
            email_address_is_preferred         => 'new1',
        }
    );

    ok(
        $resultset->is_valid(),
        'resultset with no email addresses is valid'
    );

    is_deeply(
        $resultset->results_as_hash(), {
            email_address_is_preferred => 'new1',
            allows_email               => 1,
        },
        'got expected results back (no email address data'
    );
}

done_testing();

sub _error_breakdown {
    my $errors = shift;

    my %break;

    for my $key ( keys %{$errors} ) {
        $break{$key}
            = [ map { [ $_->message()->category(), $_->message()->text() ] }
                @{ $errors->{$key} } ];
    }

    return \%break;
}
