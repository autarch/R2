use strict;
use warnings;

use Test::Exception;
use Test::More;

use lib 't/lib';
use R2::Test::RealSchema;

use List::AllUtils qw( first );
use R2::Schema::Account;
use R2::Schema::Address;
use R2::Schema::AddressType;
use R2::Schema::Person;
use R2::Schema::User;

my $account = R2::Schema::Account->new( name => q{Judean People's Front} );

{
    eval {
        R2::Schema::AddressType->insert(
            name       => 'Test0',
            account_id => $account->account_id(),
        );
    };

    my $e = $@;
    ok(
        $e,
        'cannot create a new address type which does not apply to anything'
    );
    can_ok( $e, 'errors' );

    my @e = @{ $e->errors() };
    is(
        $e[0]->{text},
        q{An address type must apply to a person, household, or organization.},
        '... got an appropriate error message in the exception'
    );
}

{
    my $type = R2::Schema::AddressType->insert(
        name                    => 'Test1',
        applies_to_person       => 0,
        applies_to_household    => 0,
        applies_to_organization => 1,
        account_id              => $account->account_id(),
    );

    eval { $type->update( applies_to_organization => 0 ); };

    my $e = $@;
    ok(
        $e,
        'cannot update an address type so that it does not apply to anything'
    );
    can_ok( $e, 'errors' );

    my @e = @{ $e->errors() };
    is(
        $e[0]->{text},
        q{An address type must apply to a person, household, or organization.},
        '... got an appropriate error message in the exception'
    );
}

{
    my $type = R2::Schema::AddressType->insert(
        name                    => 'Test2',
        applies_to_person       => 1,
        applies_to_household    => 1,
        applies_to_organization => 1,
        account_id              => $account->account_id(),
    );

    is_deeply(
        [ $type->contact_types_applied_to() ],
        [ 'Person', 'Household', 'Organization' ],
        'contact_types_applied_to returns all contact types'
    );

    my $person = R2::Schema::Person->insert(
        first_name => 'Joe',
        account_id => $account->account_id(),
        user       => R2::Schema::User->SystemUser(),
    );

    R2::Schema::Address->insert(
        city            => 'Minneapolis',
        address_type_id => $type->address_type_id(),
        country         => 'us',
        contact_id      => $person->contact_id(),
        user            => R2::Schema::User->SystemUser(),
    );

    $type->update(
        applies_to_person    => 0,
        applies_to_household => 0,
    );

    ok(
        $type->applies_to_person(),
        'trying to update an address type so it no longer applies to a type'
            . ' for which it has addresses silently ignores that part of the update.'
    );

    ok(
        !$type->applies_to_household(),
        'type no longer applies to household after update'
    );

    is_deeply(
        [ $type->contact_types_applied_to() ],
        [ 'Person', 'Organization' ],
        'contact_types_applied_to returns Person and Organization'
    );
}

done_testing();
