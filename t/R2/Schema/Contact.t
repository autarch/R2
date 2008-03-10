use strict;
use warnings;

use Test::More tests => 1;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use_ok( 'R2::Schema::Contact' );
