package R2::Model::PersonMessaging;

use strict;
use warnings;

use R2::Model::MessagingProvider;
use R2::Model::Person;
use R2::Model::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Model::Schema->Schema();

    has_table( $schema->table('PersonMessaging') );

    has_one( $schema->table('Person') );

    has_one 'provider' =>
        ( table => $schema->table('PersonMessaging') );
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
