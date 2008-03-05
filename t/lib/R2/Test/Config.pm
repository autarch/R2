package R2::Config; # intentionally not R2::Test::Config

use strict;
use warnings;

$INC{'R2/Config.pm'} = 1;

use File::Temp qw( tempdir );


sub ShareDir
{
    return 't/R2/Web/share';
}

{
    my $VarLibDir = tempdir( CLEANUP => 1 );

    sub VarLibDir
    {
        return $VarLibDir;
    }
}

1;
