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
        username   => 'joe.smith@example.com',
        first_name => 'Joe',
        last_name  => 'Smith',
        password   => 'password',
        account_id => $account->account_id(),
        role_id    => R2::Schema::Role->Member()->role_id(),
        user       => R2::Schema::User->SystemUser,
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

    is(
        $user->person()->preferred_email_address()->email_address(),
        'joe.smith@example.com',
        'creating a user creates an email address for the associated person'
    );
}

{
    my $user = R2::Schema::User->insert(
        username    => 'bubba.smith@example.com',
        first_name  => 'Bubba',
        last_name   => 'Smith',
        is_disabled => 1,
        account_id  => $account->account_id(),
        role_id     => R2::Schema::Role->Member()->role_id(),
        user        => R2::Schema::User->SystemUser,
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
        username   => 'joe.smith2@example.com',
        password   => 'password',
        date_style => 'American',
        user       => R2::Schema::User->SystemUser,
    );

    my $dt = DateTime->new(
        year   => 2008,
        month  => 5,
        day    => 23,
        hour   => 17,
        minute => 24,
    );

    is(
        $user->format_date($dt), 'May 23, 2008',
        'format_date'
    );

    $dt->set( year => DateTime->today()->year() );

    is(
        $user->format_date($dt), 'May 23',
        'format_date for same year'
    );

    $user = R2::Schema::User->insert(
        username   => 'joe.smith3@example.com',
        password   => 'password',
        date_style => 'European',
        user       => R2::Schema::User->SystemUser,
    );

    $dt->set( year => 2008 );

    is(
        $user->format_date($dt), '23 May 2008',
        'format_date'
    );

    $dt->set( year => DateTime->today()->year() );

    is(
        $user->format_date($dt), '23 May',
        'format_date for same year'
    );

    $user = R2::Schema::User->insert(
        username   => 'joe.smith4@example.com',
        password   => 'password',
        date_style => 'YMD',
        user       => R2::Schema::User->SystemUser,
    );

    $dt->set( year => 2008 );

    is(
        $user->format_date($dt), '2008-05-23',
        'format_date'
    );

    $dt->set( year => DateTime->today()->year() );

    is(
        $user->format_date($dt), '05-23',
        'format_date for same year'
    );

    is(
        $user->format_time($dt),
        '5:24 PM',
        'format_time - 12 hour time'
    );

    $user = R2::Schema::User->insert(
        username         => 'joe.smith5@example.com',
        password         => 'password',
        use_24_hour_time => 1,
        user             => R2::Schema::User->SystemUser,
    );

    is(
        $user->format_time($dt),
        '17:24',
        'format_time - 24 hour time'
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
