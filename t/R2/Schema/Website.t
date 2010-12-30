use strict;
use warnings;

use Test::More;

use lib 't/lib';

use R2::Test::RealSchema;

use R2::Schema::Account;
use R2::Schema::Person;
use R2::Schema::User;
use R2::Schema::Website;

my $account = R2::Schema::Account->new( name => q{Judean People's Front} );

my $contact = R2::Schema::Person->insert(
    first_name => 'Bob',
    account_id => $account->account_id(),
    user       => R2::Schema::User->SystemUser(),
)->contact();

{
    my $website = $contact->add_website(
        uri  => 'urth.org',
        user => R2::Schema::User->SystemUser(),
    );

    is(
        $website->uri(), 'http://urth.org/',
        'uri gets canonicalized with a scheme if needed'
    );
}

{
    eval {
        $contact->add_website(
            uri  => 'urth',
            user => R2::Schema::User->SystemUser(),
        );
    };

    ok( $@, 'cannot create a new website with an invalid uri' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is(
        $e[0]->{message}, q{"urth" is not a valid web address.},
        'got expected error message'
    );
}

{
    eval {
        $contact->add_website(
            uri  => 'urth.foo',
            user => R2::Schema::User->SystemUser(),
        );
    };

    ok( $@, 'cannot create a new website with an invalid uri' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is(
        $e[0]->{message}, q{"urth.foo" is not a valid web address.},
        'got expected error message'
    );
}

done_testing();
