package R2::Schema::Organization;

use strict;
use warnings;

use R2::Schema::Contact;
use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Organization') );

    has_one 'contact' =>
        ( table   => $schema->table('Contact'),
          handles => [ grep { ! __PACKAGE__->meta()->has_attribute($_) }
                       R2::Schema::Contact->DelegatableMethods(),
                     ],
        );
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
