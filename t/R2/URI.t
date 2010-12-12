use strict;
use warnings;

use Test::More tests => 9;

use lib 't/lib';

use R2::Test::Config;
use R2::Config;
use R2::URI qw( dynamic_uri static_uri );

{
    is(
        dynamic_uri( path => '/foo/bar' ),
        '/foo/bar',
        'dynamic_uri() with no path prefix'
    );

    is(
        dynamic_uri( path => '/foo/bar', query => { a => 1 } ),
        '/foo/bar?a=1',
        'dynamic_uri() with no path prefix'
    );

    is(
        static_uri('/css/base.css'),
        '/css/base.css',
        'static_uri() with no path prefix'
    );

    is(
        dynamic_uri( path => '' ),
        '/',
        'dynamic_uri() with no path prefix or path'
    );

    is(
        static_uri(''),
        '/',
        'static_uri() with no path prefix or path'
    );

    R2::Config->new()->_set_static_path_prefix('/12982');

    is(
        dynamic_uri( path => '/foo/bar' ),
        '/foo/bar',
        'dynamic_uri() with no path prefix'
    );

    is(
        static_uri('/css/base.css'),
        '/12982/css/base.css',
        'static_uri() with a static path prefix'
    );

    R2::Config->new()->_set_path_prefix('/r2');

    is(
        dynamic_uri( path => '/foo/bar' ),
        '/r2/foo/bar',
        'dynamic_uri() with path prefix'
    );

    is(
        dynamic_uri( path => '' ),
        '/r2',
        'dynamic_uri() with path prefix but no path'
    );
}
