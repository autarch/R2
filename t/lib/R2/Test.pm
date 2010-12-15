package R2::Test;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw( mock_schema mock_dbh );

use DBD::Mock 1.36;
use Fey::ORM::Mock;
use R2::Test::FakeSchema;
use R2::Schema;

my $IsMocked = 0;

sub mock_schema {
    require R2::Schema;

    $IsMocked = 1;

    return Fey::ORM::Mock->new( schema_class => 'R2::Schema' );
}

sub mock_dbh {
    mock_schema unless $IsMocked;

    return R2::Schema->DBIManager()->default_source()->dbh();
}

1;
