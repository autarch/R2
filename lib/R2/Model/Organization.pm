package R2::Model::Organization;

use strict;
use warnings;

use R2::Model::Party;
use R2::Model::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Model::Schema->Schema();

    has_table( $schema->table('Organization') );

    has_one 'party' =>
        ( table   => $schema->table('Party'),
          handles => [ grep { ! __PACKAGE__->meta()->has_attribute($_) }
                       map { $_->name() }
                       R2::Model::Party->Table()->columns() ],
        );
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
