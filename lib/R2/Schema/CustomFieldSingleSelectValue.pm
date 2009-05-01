package R2::Schema::CustomFieldSingleSelectValue;

use strict;
use warnings;

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomFieldSingleSelectValue') );

    has_one 'option' =>
        ( table => $schema->table('CustomFieldSelectOption'),
        );

    has 'value' =>
        ( is  => 'ro',
          isa => 'Str',
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

with 'R2::Role::Schema::CustomFieldValue'
    => { value_column => 'custom_field_select_option_id' };


no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;
