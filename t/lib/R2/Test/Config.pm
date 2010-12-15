package R2::Test::Config;

use strict;
use warnings;

use File::Slurp qw( write_file );
use File::Temp qw( tempdir );

sub import {
    my $etc     = tempdir( CLEANUP => 1 );
    my $var_lib = tempdir( CLEANUP => 1 );
    my $cache   = tempdir( CLEANUP => 1 );

    my $config = <<"EOF";
[dirs]
etc     = $etc
share   = t/R2/Web/share
var_lib = $var_lib
cache   = $cache
EOF

    my $conf_file = "$etc/r2.conf";
    write_file( $conf_file, $config );

    $ENV{R2_CONFIG} = $conf_file;
}

1;
