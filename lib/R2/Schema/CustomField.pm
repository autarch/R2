package R2::Schema::CustomField;

use strict;
use warnings;

use R2::CustomFieldType;
use R2::Schema;
use Scalar::Util qw( blessed );

use Fey::ORM::Table;

with 'R2::Role::DataValidator';


{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomField') );

    has_one 'group' =>
        ( table => $schema->table('CustomFieldGroup') );

    transform 'type'
        => inflate { R2::CustomFieldType->new( type => $_[1] ) }
        => deflate { blessed $_[1] ? $_[1]->type() : $_[1] };
}


no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;
