package R2::Schema::ContactEmail;

use strict;
use warnings;
use namespace::autoclean;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('ContactEmail') );

    has_one( $schema->table('Contact') );

    has_one( $schema->table('Email') );
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
