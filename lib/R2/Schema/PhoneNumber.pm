package R2::Schema::PhoneNumber;

use strict;
use warnings;

use R2::Schema::Contact;
use R2::Schema::PhoneNumberType;
use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('PhoneNumber') );

    has_one( $schema->table('Contact') );

    has_one 'type' =>
        ( table => $schema->table('PhoneNumberType') );
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
