package R2::Schema::CustomFieldDateValue;

use strict;
use warnings;
use namespace::autoclean;

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomFieldDateValue') );
}

sub _ValidateValue {
    my $class = shift;
    my $p     = shift;

    my $orig = $p->{value};

    # XXX - need validation!
    return;

    return {
        field => 'custom_field_' . $p->{custom_field_id},
        text =>
            "The value you provided ($orig), does not look like a date.",
    };
}

with 'R2::Role::Schema::CustomFieldValue';

__PACKAGE__->meta()->make_immutable();

1;
