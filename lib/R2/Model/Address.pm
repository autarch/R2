package R2::Model::Address;

use strict;
use warnings;

use R2::Model::AddressType;
use R2::Model::Party;
use R2::Model::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Model::Schema->Schema();

    has_table( $schema->table('Address') );

    has_one( $schema->table('Party') );

    has_one 'type' =>
        ( table => $schema->table('AddressType') );
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
