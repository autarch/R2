package R2::Role::Schema::MemberOfSomething;

use strict;
use warnings;
use namespace::autoclean;

use Moose::Role;

sub other_contact_id_for_history {
    my $self = shift;

    return $self->person_id();
}

sub summary {
    my $self = shift;

    my $summary = $self->person()->display_name();

    $summary .= ' as ' . $self->position()
        unless string_is_empty( $self->position() );

    return $summary;
}

1;
