package R2::Schema::CustomFieldSelectOption;

use strict;
use warnings;
use namespace::autoclean;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomFieldSelectOption') );
}

with 'R2::Role::Schema::HasDisplayOrder' =>
    { related_column => __PACKAGE__->Table()->column('custom_field_id') };

__PACKAGE__->meta()->make_immutable();

1;
