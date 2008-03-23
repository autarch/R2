use strict;
use warnings;

use Test::More tests => 3;

use lib 't/lib';
use R2::Test::Config;

use File::Slurp qw( read_file );
use R2::Web::Javascript;


R2::Config->new()->_set_is_production(1);

R2::Web::Javascript->new()->create_single_file();
my $js = read_file( R2::Web::Javascript->_target_file()->stringify() );


like( $js, qr{\Q/* Generated at\E \d{4}-\d\d-\d\d \d\d:\d\d:\d\d.\d+},
      'generated file contains comment with timestamp' );
like( $js, qr{R2A\.js.+R2C\.js.+R2B\.js.+R2\.js}sm,
      'generated file contains comment with original file names, and they appear in the expected order' );
like( $js, qr[\Qhas_multiple_lines(){1;2;}],
      'generated file is squished' );
