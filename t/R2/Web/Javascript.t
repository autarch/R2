use strict;
use warnings;

use Test::More tests => 2;

use lib 't/lib';
use R2::Test::Config;

use File::Slurp qw( read_file );
use R2::Web::Javascript;


R2::Web::Javascript->CreateSingleFile();
my $js = read_file( R2::Web::Javascript->_target_file()->stringify() );


like( $js, qr{\Q/* Generated at\E \d{4}-\d\d-\d\d \d\d:\d\d:\d\d.\d+},
      'generated file contains comment with timestamp' );
like( $js, qr{R2A\.js.+R2C\.js.+R2B\.js.+R2\.js}sm,
      'generated file contains comment with original file names, and they appear in the expected order' );
