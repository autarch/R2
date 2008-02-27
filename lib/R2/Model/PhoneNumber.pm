package R2::Model::PhoneNumber;

use strict;
use warnings;

use R2::Model::Party;
use R2::Model::PhoneNumberType;
use R2::Model::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Model::Schema->Schema();

    has_table( $schema->table('PhoneNumber') );

    has_one( $schema->table('Party') );

    has_one 'type' =>
        ( table => $schema->table('PhoneNumberType') );
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
