package R2::Schema::ContactNote;

use strict;
use warnings;
use namespace::autoclean;

use DateTime::Format::Natural;
use R2::Schema;
use R2::Schema::Contact;
use R2::Types qw( NonEmptyStr );
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator' =>
    { steps => [qw( _valid_note_datetime )] };
with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('ContactNote') );

    has_one( $schema->table('User') );

    has_one type => ( table => $schema->table('ContactNoteType') );

    has_one( $schema->table('Contact') );

    has truncated_note => (
        is       => 'ro',
        isa      => NonEmptyStr,
        init_arg => undef,
        lazy     => 1,
        builder  => '_build_truncated_note',
    );
}

sub _valid_note_datetime {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if string_is_empty( $p->{note_datetime} );

    return if blessed $p->{note_datetime};

    my $parser = DateTime::Format::Natural->new(
        time_zone => 'floating',
    );

    my $dt = $parser->parse_datetime( $p->{note_datetime} );

    return {
        field   => 'note_datetime',
        message => 'This does not seem to be a valid date/time.',
        }
        unless $dt && !$parser->error();

    $p->{note_datetime} = $dt;

    return;
}

sub _base_uri_path {
    my $self = shift;

    return $self->contact()->_base_uri_path() . '/note/'
        . $self->contact_note_id();
}

{
    my $MaxLength = 100;

    sub _build_truncated_note {
        my $self = shift;

        my $note = $self->note();

        my $para = ( split /\n{2,}/, $note )[0];

        if ( length $para > $MaxLength ) {
            my $space_idx = rindex( substr( $para, 0, $MaxLength ), q{ } );
            $para = substr( $para, 0, $space_idx );
            $para .= ' ...';
        }

        return $para;
    }
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
