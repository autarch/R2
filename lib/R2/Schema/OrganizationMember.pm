package R2::Schema::OrganizationMember;

use strict;
use warnings;

use R2::Schema;
use R2::Schema::Organization;
use R2::Schema::Person;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('OrganizationMember') );

    has_one( $schema->table('Organization') );
    has_one( $schema->table('Person') );
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
