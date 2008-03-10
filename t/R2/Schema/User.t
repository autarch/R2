use strict;
use warnings;

use Test::More tests => 8;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Schema::User;


my $dbh = mock_dbh();

{
    my $user =
        R2::Schema::User->insert( first_name    => 'Joe',
                                 last_name     => 'Smith',
                                 email_address => 'joe.smith@example.com',
                                 password      => 'password',
                                 website       => 'http://example.com',
                               );

    ok( $user->person(), 'newly created user has a person' );
    is( $user->person()->person_id(), 1, 'person_id == 1' );

    is( $user->person()->email_address(), 'joe.smith@example.com',
        'data for person is passed through on user insert' );
    is( $user->email_address(), 'joe.smith@example.com',
        'attributes of person are available as user methods' );

    is( length $user->password(), 86,
        'password was SHA512 digested' );
}

{
    my $user =
        R2::Schema::User->insert( first_name    => 'Bubba',
                                 last_name     => 'Smith',
                                 email_address => 'bubba.smith@example.com',
                                 website       => 'http://example.com',
                                 disable_login => 1,
                               );

    is( $user->password(), '*disabled*',
        'password is disabled' );
}


{
    eval
    {
        R2::Schema::User->insert( first_name => 'Bubba',
                                 last_name  => 'Smith',
                                 website    => 'http://example.com',
                                 password   => 'whatever',
                               );
    };

    like( $@, qr/requires an email address/,
          'cannot insert user without email address' );
}

{
    my $user =
        R2::Schema::User->insert( first_name    => 'Bubba',
                                 last_name     => 'Smith',
                                 email_address => 'bubba.smith@example.com',
                                 website       => 'http://example.com',
                                 disable_login => 1,
                               );

    $dbh->{mock_add_resultset} =
        [ [ qw( person_id first_name last_name  ) ],
          [ 1, 'Bubba', 'Smith' ],
        ];

    # simpler than mucking about with mock data
    no warnings 'redefine';
    local *R2::Schema::Person::user = sub { 1 };

    eval { $user->person()->contact()->update( email_address => undef ) };

    like( $@, qr/remove an email address for a user/,
          'cannot remove an email address for a person associated with a user' );
}
