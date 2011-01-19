use strict;
use warnings;

use Test::More;

use lib 't/lib';

use File::Slurp qw( read_file );
use R2::Web::Javascript;

my $js = R2::Web::Javascript->new( squish => 1 );

$js->create_single_file();

my $content = read_file( $js->target_file()->stringify() );

like(
    $content, qr{\Q/* Generated at\E \d{4}-\d\d-\d\d \d\d:\d\d:\d\d.\d+},
    'generated file contains comment with timestamp'
);
like(
    $content, qr[\Qvar JSAN = { "use": function () {} };],
    'generated file contains expected header'
);
like(
    $content, qr{\Q/* /home/autarch/projects/R2/share/js-source/R2.js */},
    'generated file contains comment with original file names'
);

done_testing();
