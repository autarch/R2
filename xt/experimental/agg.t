use strict;
use warnings;

use Test::Aggregate;

my $agg = Test::Aggregate->new( { dirs => 't/R2', verbose => 2 } );
$agg->run();
