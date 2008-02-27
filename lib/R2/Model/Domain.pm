package R2::Model::Domain;

use strict;
use warnings;

use R2::Model::Account;
use R2::Model::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Model::Schema->Schema();

    has_table( $schema->table('Domain') );

    has_many 'accounts' =>
        ( table => $schema->table('Account') );
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
