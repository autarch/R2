package R2::Schema::Country;

use strict;
use warnings;

use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Country') );
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
