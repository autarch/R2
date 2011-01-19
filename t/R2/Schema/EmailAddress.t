use strict;
use warnings;

use Test::More;

use lib 't/lib';

use R2::Test::RealSchema;

use R2::Schema::Account;
use R2::Schema::EmailAddress;
use R2::Schema::Person;
use R2::Schema::User;

my $account = R2::Schema::Account->new( name => q{Judean People's Front} );

my $contact = R2::Schema::Person->insert(
    first_name => 'Bob',
    account_id => $account->account_id(),
    user       => R2::Schema::User->SystemUser(),
)->contact();

{
    eval {
        R2::Schema::EmailAddress->insert(
            email_address => '@example.com',
            contact_id    => $contact->contact_id(),
            user          => R2::Schema::User->SystemUser(),
        );
    };

    ok( $@, 'cannot create a new email address with an invalid address' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is(
        $e[0]->{message}, q{"@example.com" is not a valid email address.},
        'got expected error message'
    );
}

{
    eval {
        R2::Schema::EmailAddress->insert(
            email_address => 'bob@not a domain.com',
            contact_id    => $contact->contact_id(),
            user          => R2::Schema::User->SystemUser(),
        );
    };

    ok( $@, 'cannot create a new email address with an invalid address' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is(
        $e[0]->{message},
        q{"bob@not a domain.com" is not a valid email address.},
        'got expected error message'
    );
}

done_testing();
