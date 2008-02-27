package R2::Test;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw( mock_dbh );

use DBD::Mock 1.36;


sub mock_dbh
{
    require R2::Model::Schema;

    my $man = R2::Model::Schema->DBIManager();

    $man->remove_source('default');
    $man->add_source( name => 'default', dsn => 'dbi:Mock:' );

    return $man->default_source()->dbh();
}

1;
