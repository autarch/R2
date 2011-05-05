package R2::Web::Form::ContactNoteTypes;

use Moose;
use Chloro;

use namespace::autoclean;

use Moose::Meta::Class;
use R2::Role::Web::ResultSet::NewAndExistingGroups;
use R2::Types qw( NonEmptyStr );

with 'R2::Role::Web::Form';

group contact_note_type => (
    repetition_key => 'contact_note_type_id',
    (
        field description => (
            isa      => NonEmptyStr,
            required => 1,
        )
    )
);

{
    my $Class = Moose::Meta::Class->create_anon_class(
        superclasses => ['Chloro::ResultSet'],
        roles        => [
            R2::Role::Web::ResultSet::NewAndExistingGroups->meta()
                ->generate_role(
                parameters => { group => 'contact_note_type' }
                )
        ],
        weaken => 0,
    );

    $Class->make_immutable();
}

sub _resultset_class { $Class->name() }

__PACKAGE__->meta()->make_immutable();

1;
