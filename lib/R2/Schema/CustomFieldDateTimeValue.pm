package R2::Schema::CustomFieldDateTimeValue;

use strict;
use warnings;

use Fey::ORM::Table;

with 'R2::Role::DataValidator';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomFieldDateTimeValue') );
}

sub _ValidateValue
{
    my $class = shift;
    my $p     = shift;

    my $orig = $p->{value};

    # XXX - need validation!
    return;

    return { field   => 'custom_field_' . $p->{custom_field_id},
             message => "The value you provided ($orig), does not look like a date/time.",
           };
}

with 'R2::Role::CustomFieldValue';

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;
