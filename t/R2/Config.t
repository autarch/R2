use strict;
use warnings;

use Test::More tests => 7;

use File::Slurp qw( write_file );
use File::Temp qw( tempdir );
use Path::Class;
use R2::Config;


my $config = R2::Config->new();
my $file = file( tempdir( CLEANUP => 1 ), 'r2.conf' );

{
    local $ENV{R2_CONFIG} = '/ this best not be a real / path';

    eval { $config->_find_config_file() };

    like( $@, qr/nonexistent config file/i,
          'bad value for R2_CONFIG throws an error' );
}

{
    no warnings 'redefine';
    local *Path::Class::File::stringify = sub { '/ also should not / exist' };

    eval { $config->_find_config_file() };

    like( $@, qr/cannot find a config file/i,
          'error is thrown when we no config file can be found' );
}

{
    write_file( $file->stringify(), <<'EOF' );
[R2]
is_production = 1
EOF

    local $ENV{R2_CONFIG} = $file->stringify();

    eval { $config->_read_config_file() };

    like( $@, qr/must supply a value for .+ forgot_pw/,
          'if [R2] - is_production is true, then [secrets] forgot_pw is required' );
}

{
    $config->_set_config_hash( { dirs => { foo_bar => '/my/foo/bar' } } );

    is( $config->_dir( [ 'foo', 'bar' ], '/prod/default' ),
        '/my/foo/bar',
        '_dir() returns value from config as first choice' );

    $config->_set_is_production(1);
    $config->_set_config_hash( { } );

    is( $config->_dir( [ 'foo', 'bar' ], '/prod/default' ),
        '/prod/default',
        '_dir() returns prod default when is_production is true' );

    $config->_set_is_production(0);

    is( $config->_dir( [ 'foo', 'bar' ], '/prod/default', '/dev/default' ),
        '/dev/default',
        '_dir() returns dev default when is_production is true and dev default is provided' );

    $config->_set_home_dir( dir( '/my/home' ) );

    is( $config->_dir( [ 'foo', 'bar' ], '/prod/default' ),
        '/my/home/.r2/foo/bar',
        '_dir() returns dir under $HOME/.r2 as final fallback' );
}
