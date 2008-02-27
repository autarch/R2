package R2::Model::Donation;

use strict;
use warnings;

use R2::Model::Fund;
use R2::Model::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Model::Schema->Schema();

    has_table( $schema->table('Donation') );

    has_one( $schema->table('Fund') );

    has_one( $schema->table('Party') );

}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
