package R2::Schema;

use strict;
use warnings;

use DBI;
use Fey::ORM::Schema;
use Fey::DBIManager::Source;
use Fey::Loader;
use R2::Config;


my $source;
if ($R2::Schema::TestSchema)
{
    has_schema $R2::Schema::TestSchema
}
else
{
    my $dbi_config = R2::Config->new()->dbi_config();

    my $source =
        Fey::DBIManager::Source->new( %{ $dbi_config },
                                      post_connect => \&_set_dbh_attributes,
                                    );

    my $schema = Fey::Loader->new( dbh => $source->dbh() )->make_schema();

    has_schema $schema;

    __PACKAGE__->DBIManager()->add_source($source);
}

sub _set_dbh_attributes
{
    my $dbh = shift;

    $dbh->{pg_enable_utf8} = 1;

    $dbh->do( 'SET TIME ZONE UTC' );

    return;
}

no Fey::ORM::Schema;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;
