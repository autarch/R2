use strict;
use warnings;

use Test::More tests => 3;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use R2::Test::Config;
use R2::Config;
use R2::Model::Domain;


mock_dbh();

{
    my $domain =
        R2::Model::Domain->insert( web_hostname   => 'www.example.com',
                                   email_hostname => 'www.example.com',
                                   requires_ssl   => 0,
                                 );

    is( $domain->uri( path => '/foo' ),
        'http://www.example.com/foo',
        'uri() for /foo' );

    R2::Config->new()->_set_static_path_prefix( '12982' );

    is( $domain->static_uri( path => '/css/base.css' ),
        'http://www.example.com/12982/css/base.css',
        'static_uri()' );
}

{
    my $domain =
        R2::Model::Domain->insert( web_hostname   => 'www.example.com',
                                   email_hostname => 'www.example.com',
                                   requires_ssl   => 1,
                                 );

    is( $domain->uri( path => '/foo' ),
        'https://www.example.com/foo',
        'ssl uri() for /foo' );

}
