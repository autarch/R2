package R2::Schema::CustomFieldMultiSelectValue;

use strict;
use warnings;

use Fey::ORM::Table;
use Moose::Util::TypeConstraints;

with 'R2::Role::Schema::DataValidator';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomFieldMultiSelectValue') );

    my $value_type = subtype as 'ArrayRef[Str]';
    coerce $value_type
        => from 'Str'
        => via { [ $_ ] };

    has 'value' =>
        ( is     => 'ro',
          isa    => $value_type,
          coerce => 1,
        );
}

sub _ValidateValue
{
    my $class = shift;
    my $p     = shift;

    my $orig = $p->{value};

    # XXX - need validation!
    return;

    return { field   => 'custom_field_' . $p->{custom_field_id},
             message => '', # XXX
           };
}

sub _replace_value_for_contact
{
    my $class           = shift;
    my $delete          = shift;
    my $custom_field_id = shift;
    my $contact_id      = shift;
    my $value           = shift;

    my $dbh = $class->_dbh($delete);

    $dbh->do( $delete->sql($dbh), {},
              $custom_field_id, $contact_id );

    $class->insert( custom_field_id => $custom_field_id,
                    contact_id      => $contact_id,
                    value           => $_,
                  )
        for @{ $value };
}

with 'R2::Role::Schema::CustomFieldValue'
    => { value_column => 'custom_field_select_option_id' };

no Fey::ORM::Table;
no Moose::Util::TypeConstraints;

__PACKAGE__->meta()->make_immutable();

1;
