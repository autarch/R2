package R2::Model::AccountUserRole;

use strict;
use warnings;

use R2::Model::Account;
use R2::Model::Role;
use R2::Schema;

# loading causes circular dep issue
#use R2::Model::User;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('AccountUserRole') );

    has_one ( $schema->table('Account') );
    has_one ( $schema->table('User') );
    has_one ( $schema->table('Role') );
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
