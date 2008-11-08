use strict;
use warnings;

use Test::More tests => 2;

use lib 't/lib';
use R2::Test qw( mock_schema );

use R2::Test::Config;
use R2::Config;
use R2::Schema::Domain;


mock_schema();

{
    my $domain =
        R2::Schema::Domain->insert( web_hostname   => 'www.example.com',
                                    email_hostname => 'www.example.com',
                                    requires_ssl   => 0,
                                  );

    is( $domain->application_uri( path => '/foo', with_host => 1 ),
        'http://www.example.com/foo',
        'uri() for /foo' );
}

{
    my $domain =
        R2::Schema::Domain->insert( web_hostname   => 'www.example.com',
                                    email_hostname => 'www.example.com',
                                    requires_ssl   => 1,
                                  );

    is( $domain->application_uri( path => '/foo', with_host => 1 ),
        'https://www.example.com/foo',
        'ssl uri() for /foo' );

}
