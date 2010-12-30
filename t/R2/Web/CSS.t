use strict;
use warnings;

use Test::More;

use lib 't/lib';

use File::Slurp qw( read_file );
use R2::Web::CSS;

my $css = R2::Web::CSS->new();

plan skip_all => 'Cannot run tests without lessc available'
    unless eval { $css->lessc_path() };

$css->create_single_file();

my $content = read_file( $css->target_file()->stringify() );

like(
    $content, qr{\Q/* Generated at\E \d{4}-\d\d-\d\d \d\d:\d\d:\d\d.\d+},
    'generated file contains comment with timestamp'
);
like(
    $content, qr{01.+\.css.+02.+\.css}sm,
    'generated file contains comment with original file names, and they appear in the expected order'
);

done_testing();
