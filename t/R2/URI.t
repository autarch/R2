use strict;
use warnings;

use Test::More tests => 2;

use lib 't/lib';

use R2::Test::Config;
use R2::Config;
use R2::URI qw( static_uri );


{
    is( static_uri('/css/base.css'),
        '/css/base.css',
        'static_uri() with no path prefix' );

    R2::Config->new()->_set_static_path_prefix( '/12982' );

    is( static_uri('/css/base.css'),
        '/12982/css/base.css',
        'static_uri() with a static path prefix' );
}
