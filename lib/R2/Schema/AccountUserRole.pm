package R2::Schema::AccountUserRole;

use strict;
use warnings;

use R2::Schema::Account;
use R2::Schema::Role;
use R2::Schema;

# loading causes circular dep issue
#use R2::Schema::User;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('AccountUserRole') );

    has_one( $schema->table('Account') );
    has_one( $schema->table('User') );
    has_one( $schema->table('Role') );
}

make_immutable;

no Fey::ORM::Table;
no Moose;

1;

__END__
