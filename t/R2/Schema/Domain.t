use strict;
use warnings;

use Test::Fatal;
use Test::More;

use lib 't/lib';
use R2::Test::RealSchema;

use R2::Config;
use R2::Schema::Domain;

{
    my $domain = R2::Schema::Domain->insert(
        web_hostname   => 'www.example.com',
        email_hostname => 'www.example.com',
        requires_ssl   => 0,
    );

    is(
        $domain->application_uri( path => '/foo', with_host => 1 ),
        'http://www.example.com/foo',
        'uri() for /foo'
    );
}

{
    my $domain = R2::Schema::Domain->insert(
        web_hostname   => 'foo.example.com',
        email_hostname => 'foo.example.com',
        requires_ssl   => 1,
    );

    is(
        $domain->application_uri( path => '/foo', with_host => 1 ),
        'https://foo.example.com/foo',
        'ssl uri() for /foo'
    );

}

{
    eval { R2::Schema::Domain->insert( web_hostname => 'foo.example.com' ) };

    my $e = $@;

    ok(
        $e,
        'got an exception trying to insert a web_hostname that already exists'
    );

    like(
        $e->full_message(),
        qr/\QThe web hostname you provided is already in use by another domain./,
        'exception contains the expected error',
    );
}

{
    eval {
        R2::Schema::Domain->insert(
            web_hostname   => 'new.example.com',
            email_hostname => 'foo.example.com',
        );
    };

    my $e = $@;

    ok(
        $e,
        'got an exception trying to insert an email_hostname that already exists'
    );
    like(
        $e->full_message(),
        qr/\QThe email hostname you provided is already in use by another domain./,
        'exception contains the expected error',
    );
}

done_testing();
