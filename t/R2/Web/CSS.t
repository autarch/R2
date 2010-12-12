use strict;
use warnings;

use Test::More tests => 4;

use lib 't/lib';
use R2::Test::Config;

use File::Slurp qw( read_file );
use R2::Web::CSS;

R2::Web::CSS->new()->create_single_file();
my $css = read_file( R2::Web::CSS->_target_file()->stringify() );

like(
    $css, qr{\Q/* Generated at\E \d{4}-\d\d-\d\d \d\d:\d\d:\d\d.\d+},
    'generated file contains comment with timestamp'
);
like(
    $css, qr{01\.css.+02\.css}sm,
    'generated file contains comment with original file names, and they appear in the expected order'
);
like(
    $css, qr[body\s*{\s*color:\s*red;\s*}],
    'body style still exists'
);
like(
    $css, qr[p\s*{\s*color:\s*blue;\s*}],
    'p style still exists'
);
