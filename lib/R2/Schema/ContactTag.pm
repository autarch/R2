package R2::Schema::ContactTag;

use strict;
use warnings;
use namespace::autoclean;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('ContactTag') );

    has_one( $schema->table('Contact') );

    has_one( $schema->table('Tag') );
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
