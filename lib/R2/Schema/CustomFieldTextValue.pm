package R2::Schema::CustomFieldTextValue;

use strict;
use warnings;

use Fey::ORM::Table;

with 'R2::Role::DataValidator';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomFieldTextValue') );
}

sub _ValidateValue
{
    my $class = shift;
    my $p     = shift;

    return if defined $p->{value} && length $p->{value};

    return { field   => 'custom_field_' . $p->{custom_field_id},
             message => 'The text field was empty.',
           };
}

with 'R2::Role::CustomFieldValue';

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;
