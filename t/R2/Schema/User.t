use strict;
use warnings;

use Test::More;

use lib 't/lib';

use R2::Test::RealSchema;

use R2::Schema::Account;
use R2::Schema::User;

my $account = R2::Schema::Account->new( name => q{Judean People's Front} );

{
    my $user = R2::Schema::User->insert(
        first_name    => 'Joe',
        last_name     => 'Smith',
        email_address => 'joe.smith@example.com',
        password      => 'password',
        account_id    => $account->account_id(),
        role_id       => R2::Schema::Role->Member()->role_id(),
        user          => R2::Schema::User->SystemUser,
    );

    ok( $user->person(), 'newly created user has a person' );

    is(
        $user->username(), 'joe.smith@example.com',
        'username is same as email address'
    );

    is(
        length $user->password(), 67,
        'password was crypted'
    );
}

{
    my $user = R2::Schema::User->insert(
        first_name    => 'Bubba',
        last_name     => 'Smith',
        email_address => 'bubba.smith@example.com',
        is_disabled   => 1,
        account_id    => $account->account_id(),
        role_id       => R2::Schema::Role->Member()->role_id(),
        user          => R2::Schema::User->SystemUser,
    );

    is(
        $user->password(), '*disabled*',
        'when user is marked disabled, password is set to unusable password by default'
    );
}

{
    eval {
        R2::Schema::User->insert(
            first_name => 'Bubba',
            last_name  => 'Smith',
            password   => 'whatever',
            account_id => $account->account_id(),,
            role_id    => R2::Schema::Role->Member()->role_id(),
            user       => R2::Schema::User->SystemUser,
        );
    };

    ok( $@, 'cannot create a new user without a username or email address' );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is(
        $e[0]->{message}, q{A user must have a username or email address.},
        'got expected error message'
    );
}

{
    eval {
        R2::Schema::User->insert(
            username   => 'bubba',
            first_name => 'Bubba',
            last_name  => 'Smith',
            account_id => $account->account_id(),,
            role_id    => R2::Schema::Role->Member()->role_id(),
            user       => R2::Schema::User->SystemUser,
        );
    };

    ok(
        $@,
        'cannot create a new user without a password (or setting is_disabled to true)'
    );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is(
        $e[0]->{message}, q{You must provide a password.},
        'got expected error message'
    );
}

{
    my $user = R2::Schema::User->insert(
        first_name    => 'Joe',
        last_name     => 'Smith',
        email_address => 'joe.smith2@example.com',
        password      => 'password',
        locale_code   => 'fr_FR',
        account_id    => $account->account_id(),
        role_id       => R2::Schema::Role->Member()->role_id(),
        user          => R2::Schema::User->SystemUser,
    );

    my $dt = DateTime->new(
        year   => 2008,
        month  => 5,
        day    => 23,
        hour   => 7,
        minute => 24,
    );

    is(
        $user->format_date($dt), '23 mai 2008',
        'format_date'
    );

    is(
        $user->format_datetime($dt), '23 mai 2008 07:24:00',
        'format_datetime'
    );
}

{
    my $user = R2::Schema::User->insert(
        first_name => 'Joe',
        last_name  => 'Smith',
        username   => 'joe.smith',
        password   => 'password',
        account_id => $account->account_id(),
        role_id    => R2::Schema::Role->Member()->role_id(),
        user       => R2::Schema::User->SystemUser,
    );

    is(
        $user->username(), 'joe.smith',
        'the username does not need to be an email address'
    );
}

done_testing();
