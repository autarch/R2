use strict;
use warnings;

use Test::Exception;
use Test::More tests => 2;

use R2::Schema;


lives_ok( sub { R2::Schema->LoadAllClasses() },
          'LoadAllClasses lives' );
ok( $INC{'R2/Schema/Account.pm'},
    'loaded R2::Schema::Account' );
