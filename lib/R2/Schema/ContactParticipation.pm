package R2::Schema::ContactParticipation;

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
    { steps => [qw( _valid_activity_datetime )] };
with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('ContactParticipation') );

    has_one( $schema->table('Activity') );

    has_one type => ( table => $schema->table('ParticipationType') );

    has_one( $schema->table('Contact') );
}

sub _valid_start_date {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if string_is_empty( $p->{start_date} );

    return if blessed $p->{start_date};

    my $parser = DateTime::Format::Natural->new(
        time_zone => 'floating',
    );

    my $dt = $parser->parse_datetime( $p->{start_date} );

    return {
        field   => 'start_date',
        message => 'This does not seem to be a valid date/time.',
        }
        unless $dt && !$parser->error();

    $p->{start_date} = $dt;

    return;
}

sub _valid_end_date {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if string_is_empty( $p->{end_date} );

    return if blessed $p->{end_date};

    my $parser = DateTime::Format::Natural->new(
        time_zone => 'floating',
    );

    my $dt = $parser->parse_datetime( $p->{end_date} );

    return {
        field   => 'end_date',
        message => 'This does not seem to be a valid date/time.',
        }
        unless $dt && !$parser->error();

    $p->{end_date} = $dt;

    return;
}

sub _base_uri_path {
    my $self = shift;

    return
          $self->activity()->_base_uri_path()
        . '/participation/'
        . $self->contact_participation_id();

}

__PACKAGE__->meta()->make_immutable();

1;

__END__
