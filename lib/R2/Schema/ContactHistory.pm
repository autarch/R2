package R2::Schema::ContactHistory;

use strict;
use warnings;

use DateTime::Format::Strptime;
use List::AllUtils qw( first );
use R2::Schema;
use R2::Schema::Contact;

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator';
with 'R2::Role::Schema::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('ContactHistory') );

    has_one type => ( table => $schema->table('ContactHistoryType') );

    has_one $schema->table('User');

    has_one contact => (
        table => $schema->table('Contact'),
        fk    => (
            first { $_->source_columns()->[0]->name() eq 'contact_id' }
            $schema->foreign_keys_for_table('Contact')
        )
    );

    has_one email_address => ( table => $schema->table('EmailAddress') );

    has_one( $schema->table('Website') );

    has_one( $schema->table('Address') );

    has_one phone_number => ( table => $schema->table('PhoneNumber') );

    has_one other_contact => (
        table => $schema->table('Contact'),
        fk    => (
            first { $_->source_columns()->[0]->name() eq 'other_contact_id' }
            $schema->foreign_keys_for_table('Contact')
        )
    );
}

sub _base_uri_path {
    my $self = shift;

    return
          $self->contact()->_base_uri_path()
        . '/history/'
        . $self->contact_history_id();
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
