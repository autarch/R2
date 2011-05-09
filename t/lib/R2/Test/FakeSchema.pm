package R2::Test::FakeSchema;

use strict;
use warnings;

$ENV{R2_MOCK_SCHEMA} = 1;

require R2::Schema;

1;
