package R2::Schema::CustomFieldIntegerValue;

use strict;
use warnings;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomFieldIntegerValue') );
}

sub _ValidateValue
{
    my $class = shift;
    my $p     = shift;

    my $orig = $p->{value};

    $p->{value} =~ s/^\$//;
    $p->{value} =~ s/,//g;

    return if $p->{value} =~ /^-?\d+$/;

    return { field   => 'custom_field_' . $p->{custom_field_id},
             message => "The value you provided ($orig), does not look like an integer.",
           };
}

with 'R2::Role::CustomFieldValue';

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;
