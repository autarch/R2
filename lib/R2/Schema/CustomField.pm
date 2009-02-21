package R2::Schema::CustomField;

use strict;
use warnings;

use R2::CustomFieldType;
use R2::Schema;
use Scalar::Util qw( blessed );

use Fey::ORM::Table;

with 'R2::Role::DataValidator';


{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomField') );

    has_one 'group' =>
        ( table => $schema->table('CustomFieldGroup') );

    transform 'type'
        => inflate { R2::CustomFieldType->new( type => $_[1] ) }
        => deflate { blessed $_[1] ? $_[1]->type() : $_[1] };

    has 'value_count' =>
        ( is         => 'ro',
          isa        => 'Int',
          lazy_build => 1,
        );

    has '_value_count_select' =>
        ( is         => 'ro',
          isa        => 'Fey::SQL::Select',
          lazy_build => 1,
        );
}


sub is_deletable
{
    my $self = shift;

    return $self->value_count() ? 0 : 1;
}

sub _build_value_count
{
    my $self = shift;

    my $select = $self->_value_count_select();

    my $dbh = $self->_dbh($select);

    my $row =
        $dbh->selectrow_arrayref( $select->sql($dbh), {}, $select->bind_params() );

    return $row ? $row->[0] : 0;
}

sub _build__value_count_select
{
    my $self = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $value_table = $schema->table( $self->type()->table() );

    my $count =
        Fey::Literal::Function->new( 'COUNT', $value_table->column('custom_field_id') );

    $select->select($count)
           ->from($value_table)
           ->where( $value_table->column('custom_field_id'),
                    '=', $self->custom_field_id() );

    return $select;
}

no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;
