package R2::Schema::ContactHistory;

use strict;
use warnings;

use DateTime::Format::Pg;
use DateTime::Format::Strptime;
use R2::Schema;
use R2::Schema::Contact;

use Fey::ORM::Table;

with 'R2::Role::DataValidator', 'R2::Role::URIMaker';


{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('ContactHistory') );

    transform 'creation_datetime' =>
        deflate { blessed $_[1] ? DateTime::Format::Pg->format_datetime( $_[1] ) : $_[1] },
        inflate { defined $_[1] ? DateTime::Format::Pg->parse_datetime( $_[1] ) : $_[1] };

    has_one type =>
        ( table => $schema->table('ContactHistoryType') );

    has_one( $schema->table('Contact') );
}

sub _base_uri_path
{
    my $self = shift;

    return $self->contact()->_base_uri_path() . '/history/' . $self->donation_id();
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
