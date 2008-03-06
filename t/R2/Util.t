use strict;
use warnings;

use Test::More tests => 4;

use R2::Util qw( string_is_empty );


ok( string_is_empty(undef), 'undef is an empty string' );
ok( string_is_empty(''), q{'' is an empty string} );
ok( ! string_is_empty('0'), q{'0' is not an empty string} );
ok( ! string_is_empty( 'a' x 500 ), q{long string is not an empty string} );
