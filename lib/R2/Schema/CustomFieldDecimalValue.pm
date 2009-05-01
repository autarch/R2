package R2::Schema::CustomFieldDecimalValue;

use strict;
use warnings;

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomFieldDecimalValue') );
}

sub _ValidateValue
{
    my $class = shift;
    my $p     = shift;

    my $orig = $p->{value};

    $p->{value} =~ s/^\$//;
    $p->{value} =~ s/,//g;

    return if $p->{value} =~ /^-?\d+(?:\.\d+)?$/;

    return { field   => 'custom_field_' . $p->{custom_field_id},
             message => "The value you provided ($orig), does not look like a decimal value.",
           };
}

with 'R2::Role::Schema::CustomFieldValue';

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;
