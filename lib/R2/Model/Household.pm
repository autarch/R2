package R2::Model::Household;

use strict;
use warnings;

use R2::Model::Party;
use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Household') );

    has_one 'party' =>
        ( table   => $schema->table('Party'),
          handles => [ grep { ! __PACKAGE__->meta()->has_attribute($_) }
                       R2::Model::Party->DelegatableMethods(),
                     ],
        );
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
