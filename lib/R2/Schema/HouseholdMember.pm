package R2::Schema::HouseholdMember;

use strict;
use warnings;

use R2::Schema;
use R2::Schema::Household;
use R2::Schema::Person;
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;

with 'R2::Role::HistoryRecorder';


{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('HouseholdMember') );

    has_one( $schema->table('Household') );
    has_one( $schema->table('Person') );
}

sub contact_id_for_history
{
    my $self = shift;

    return $self->household_id();
}

sub other_contact_id_for_history
{
    my $self = shift;

    return $self->person_id();
}

sub summary
{
    my $self = shift;

    my $summary = $self->person()->display_name();

    $summary .= ' as ' . $self->position()
        unless string_is_empty( $self->position() );

    return $summary;
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
