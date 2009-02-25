package R2::Schema::CustomFieldSingleSelectValue;

use strict;
use warnings;

use Fey::ORM::Table;

with 'R2::Role::DataValidator';

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

with 'R2::Role::CustomFieldValue'
    => { value_column => 'custom_field_select_option_id' };


no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;
