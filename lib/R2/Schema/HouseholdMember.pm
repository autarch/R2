package R2::Schema::HouseholdMember;

use strict;
use warnings;

use R2::Schema;
use R2::Schema::Household;
use R2::Schema::Person;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('HouseholdMember') );

    has_one( $schema->table('Household') );
    has_one( $schema->table('Person') );
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
