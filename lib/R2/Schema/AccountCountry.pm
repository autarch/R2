package R2::Schema::AccountCountry;

use strict;
use warnings;

use R2::Schema::Account;
use R2::Schema::Country;
use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('AccountCountry') );

    has_one( $schema->table('Account') );
    has_one( $schema->table('Country') );
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
