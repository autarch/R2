use strict;
use warnings;

use Test::More tests => 2;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Test::Config;
use R2::Config;
use R2::Schema::Domain;


mock_dbh();

{
    my $domain =
        R2::Schema::Domain->insert( web_hostname   => 'www.example.com',
                                   email_hostname => 'www.example.com',
                                   requires_ssl   => 0,
                                 );

    is( $domain->uri( path => '/foo' ),
        'http://www.example.com/foo',
        'uri() for /foo' );
}

{
    my $domain =
        R2::Schema::Domain->insert( web_hostname   => 'www.example.com',
                                   email_hostname => 'www.example.com',
                                   requires_ssl   => 1,
                                 );

    is( $domain->uri( path => '/foo' ),
        'https://www.example.com/foo',
        'ssl uri() for /foo' );

}
