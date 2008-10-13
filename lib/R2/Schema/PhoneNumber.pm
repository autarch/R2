package R2::Schema::PhoneNumber;

use strict;
use warnings;

use R2::Schema::Contact;
use R2::Schema::PhoneNumberType;
use R2::Schema;

use Fey::ORM::Table;

with qw( R2::Role::DataValidator R2::Role::HistoryRecorder );


{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('PhoneNumber') );

    has_one( $schema->table('Contact') );

    has_one 'type' =>
        ( table => $schema->table('PhoneNumberType') );
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
