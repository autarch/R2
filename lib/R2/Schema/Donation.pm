package R2::Schema::Donation;

use strict;
use warnings;

use R2::Schema::Fund;
use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Donation') );

    has_one( $schema->table('Fund') );

    has_one( $schema->table('Contact') );

}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__