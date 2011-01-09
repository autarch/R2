package R2::Schema::CustomField;

use strict;
use warnings;
use namespace::autoclean;

use R2::CustomFieldType;
use R2::Schema;
use R2::Schema::CustomFieldDateValue;
use R2::Schema::CustomFieldDateTimeValue;
use R2::Schema::CustomFieldDecimalValue;
use R2::Schema::CustomFieldFileValue;
use R2::Schema::CustomFieldIntegerValue;
use R2::Schema::CustomFieldMultiSelectValue;
use R2::Schema::CustomFieldSingleSelectValue;
use R2::Schema::CustomFieldTextValue;
use Scalar::Util qw( blessed );

use Fey::ORM::Table;
use MooseX::Params::Validate qw( validated_list );

with 'R2::Role::Schema::DataValidator';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomField') );

    has_one 'group' => ( table => $schema->table('CustomFieldGroup') );

    has_one 'widget' => (
        table   => $schema->table('HTMLWidget'),
        handles => { widget_name => 'name' },
    );

    #<<<
    transform 'type'
        => inflate { R2::CustomFieldType->new( type => $_[1] ) }
        => handles {
            clean_value => 'clean_value',
            is_select   => 'is_select',
            type_table  => 'table',
            type_name   => 'type',
        }
        => deflate { blessed $_[1] ? $_[1]->type() : $_[1] };
    #>>>

    has 'value_count' => (
        is      => 'ro',
        isa     => 'Int',
        lazy    => 1,
        builder => '_build_value_count',
    );

    has '_value_count_select' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        lazy    => 1,
        builder => '_build_value_count_select',
    );
}

with 'R2::Role::Schema::HasDisplayOrder' =>
    { related_column => __PACKAGE__->Table()->column('custom_field_group_id') };

sub is_deletable {
    my $self = shift;

    return $self->value_count() ? 0 : 1;
}

sub _build_value_count {
    my $self = shift;

    my $select = $self->_value_count_select();

    my $dbh = $self->_dbh($select);

    my $row = $dbh->selectrow_arrayref( $select->sql($dbh), {},
        $select->bind_params() );

    return $row ? $row->[0] : 0;
}

sub _build_value_count_select {
    my $self = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $value_table = $schema->table( $self->type_table() );

    my $count = Fey::Literal::Function->new( 'COUNT',
        $value_table->column('custom_field_id') );

    #<<<
    $select
        ->select($count)
        ->from  ($value_table)
        ->where( $value_table->column('custom_field_id'),
                 '=', $self->custom_field_id() );
    #>>>
    return $select;
}

sub validate_value {
    my $self = shift;

    unless ( $self->type()->value_is_valid( $_[1] ) ) {
        my $message
            = 'The value provided for '
            . $self->label()
            . ' was not a valid '
            . $self->type()->name() . q{.};

        return {
            message => $message,
            field   => 'custom_field_' . $self->custom_field_id(),
        };
    }

    return;
}

sub set_value_for_contact {
    my $self = shift;

    my $class = Fey::Meta::Class::Table->ClassForTable( $self->type_table() );

    $class->replace_value_for_contact( field => $self, @_ );
}

sub delete_value_for_contact {
    my $self = shift;

    my $class = Fey::Meta::Class::Table->ClassForTable( $self->type_table() );

    $class->delete_value_for_contact( field => $self, @_ );
}

sub value_object {
    my $self = shift;

    my $class = Fey::Meta::Class::Table->ClassForTable( $self->type_table() );

    return $class->new( @_, _from_query => 1 );
}

__PACKAGE__->meta()->make_immutable();

1;
