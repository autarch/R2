package R2::Role::Web::ResultSet::Members;

use Moose::Role;

sub members {
    my $self = shift;

    my $result = $self->results_as_hash();

    return [
        map {
            my %pos
                = exists $result->{member}{$_}{position}
                ? ( position => $result->{member}{$_}{position} )
                : ();
            { person_id => $_, %pos };
            } keys %{ $result->{member} }
    ];
}

1;
