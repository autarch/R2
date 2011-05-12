package R2::Schema::Household;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Household') );

    class_has 'DefaultOrderBy' => (
        is   => 'ro',
        isa  => 'ArrayRef',
        lazy => 1,
        default =>
            sub { [ $schema->table('Household')->column('name') ] },
    );

    require R2::Schema::HouseholdMember;

    with 'R2::Role::Schema::HasMembers' =>
        { membership_table => $schema->table('HouseholdMember') };
}

with 'R2::Role::Schema::Serializes';

with 'R2::Role::Schema::ActsAsContact' => { steps => [] };

with 'R2::Role::Schema::HistoryRecorder';

sub display_name {
    return $_[0]->name();
}

sub _build_friendly_name {
    my $self = shift;

    return $self->name();
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
