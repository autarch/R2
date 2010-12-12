use strict;
use warnings;

use Test::More tests => 16;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use Digest::SHA qw( sha512_base64 );
use R2::Schema::User;

my $dbh = mock_dbh();

{
    my $user = R2::Schema::User->insert(
        first_name    => 'Joe',
        last_name     => 'Smith',
        email_address => 'joe.smith@example.com',
        password      => 'password',
        account_id    => 1,
    );

    ok( $user->person(), 'newly created user has a person' );
    is( $user->person()->person_id(), 1, 'person_id == 1' );

    is(
        $user->username(), 'joe.smith@example.com',
        'username is same as email address'
    );

    is(
        length $user->password(), 86,
        'password was SHA512 digested'
    );
}

{
    my $user = R2::Schema::User->insert(
        first_name    => 'Bubba',
        last_name     => 'Smith',
        email_address => 'bubba.smith@example.com',
        disable_login => 1,
        account_id    => 1,
    );

    is(
        $user->password(), '*disabled*',
        'password is disabled'
    );
}

{
    eval {
        R2::Schema::User->insert(
            first_name => 'Bubba',
            last_name  => 'Smith',
            password   => 'whatever',
            account_id => 1,
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
            first_name => 'Bubba',
            last_name  => 'Smith',
            account_id => 1,
        );
    };

    ok( $@,
        'cannot create a new user without a password (or setting disable_login to true)'
    );
    can_ok( $@, 'errors' );

    my @e = @{ $@->errors() };
    is(
        $e[0]->{message}, q{A user requires a password.},
        'got expected error message'
    );
}

{
    my $pw = 'testing';

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [
        [qw( user_id password )],
        [ 1, sha512_base64($pw) ],
    ];

    my $user = R2::Schema::User->new(
        username => 'bubba.smith@example.com',
        password => $pw,
    );

    ok( $user, 'got a user for username & password' );
}

{
    my $pw = 'testing';

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [
        [qw( user_id password )],
        [ 1, sha512_base64($pw) ],
    ];

    my $user = R2::Schema::User->new(
        username => 'bubba.smith@example.com',
        password => $pw . 'bad',
    );

    ok( !$user, 'did not get a user when the password is wrong' );
}

{
    my $user = R2::Schema::User->insert(
        first_name    => 'Joe',
        last_name     => 'Smith',
        email_address => 'joe.smith@example.com',
        password      => 'password',
        date_format   => 'MM-dd-YYY',
        time_format   => 'hh:mm a',
        account_id    => 1,
    );

    my $dt = DateTime->new( year => 2008, month => 7, day => 23, hour => 7,
        minute => 24 );
    is(
        $user->format_date($dt), '07-23-2008',
        'format_date'
    );

    is(
        $user->format_datetime($dt), '07-23-2008 07:24 AM',
        'format_datetime'
    );
}

{
    my $user = R2::Schema::User->insert(
        first_name  => 'Joe',
        last_name   => 'Smith',
        username    => 'joe.smith',
        password    => 'password',
        date_format => 'MM-dd-YYY',
        time_format => 'hh:mm a',
        account_id  => 1,
    );

    is(
        $user->username(), 'joe.smith',
        'the username does not need to be an email address'
    );
}
