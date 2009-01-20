package R2::Schema::CustomField;

use strict;
use warnings;

use R2::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with qw( R2::Role::DataValidator );


{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomField') );

    has_one 'group' =>
        ( table => $schema->table('CustomFieldGroup') );

    class_has 'Types' =>
        ( is         => 'ro',
          isa        => 'ArrayRef',
          lazy_build => 1,
        );
}


sub _build_Types
{
    my $class = shift;

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    my $sth = $dbh->column_info( '', '', 'CustomField', 'type' );

    my $col_info = $sth->fetchall_arrayref({})->[0];

    return $col_info->{pg_enum_values} || [];
}

no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;
