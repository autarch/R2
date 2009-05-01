package R2::Schema::OrganizationMember;

use strict;
use warnings;

use R2::Schema;
use R2::Schema::Organization;
use R2::Schema::Person;
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;

with 'R2::Role::Schema::HistoryRecorder';


{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('OrganizationMember') );

    has_one( $schema->table('Organization') );
    has_one( $schema->table('Person') );
}

sub contact_id_for_history
{
    my $self = shift;

    return $self->organization_id();
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
