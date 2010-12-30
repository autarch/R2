package R2::Schema::PersonMessagingProvider;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema;
use R2::Schema::Contact;
use R2::Schema::MessagingProvider;
use R2::Schema::Person;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('PersonMessagingProvider') );

    has_one( $schema->table('Person') );

    has_one 'provider' => ( table => $schema->table('MessagingProvider') );
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
