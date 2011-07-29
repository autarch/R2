package R2::Role::Schema::HasMembers;

use strict;
use warnings;
use namespace::autoclean;

use Fey::Object::Iterator::FromSelect;
use Fey::Placeholder;
use R2::Exceptions qw( data_validation_error );
use R2::Schema;
use R2::Schema::Person;
use R2::Types qw( ArrayRef HashRef Int Str );
use MooseX::Params::Validate qw( validated_list );

use MooseX::Role::Parameterized;

parameter 'membership_table' => (
    isa      => 'Fey::Table',
    required => 1,
);

has 'members' => (
    is      => 'ro',
    isa     => 'Fey::Object::Iterator::FromSelect',
    lazy    => 1,
    builder => '_build_members',
);

has 'member_count' => (
    is      => 'ro',
    isa     => Int,
    lazy    => 1,
    builder => '_build_member_count',
);

{
    my %spec = (
        person_id => { isa => Int },
        position  => { isa => Str, default => q{} },
        user      => { isa => 'R2::Schema::User' },
    );

    sub add_member {
        my $self = shift;
        my ( $person_id, $position, $user ) = validated_list( \@_, %spec );

        my $person = R2::Schema::Person->new( person_id => $person_id );

        if ( $person->account_id() != $self->account_id() ) {
            data_validation_error
                'Cannot add a person from a different account.';
        }

        my $class = ( ref $self ) . 'Member';

        $class->insert(
            $self->pk_values_hash(),
            person_id => $person_id,
            position  => $position,
            user      => $user,
        );
    }
}

{
    my %spec = (
        person_id => { isa => Int },
        user      => { isa => 'R2::Schema::User' },
    );

    sub remove_member {
        my $self = shift;
        my ( $person_id, $user ) = validated_list( \@_, %spec );

        my $class = ( ref $self ) . 'Member';

        my $member = $class->new(
            $self->pk_values_hash(),
            person_id => $person_id,
        );

        return unless $member;

        $member->delete( user => $user );

        return;
    }
}

{
    my %spec = (
        members => { isa => ArrayRef [HashRef] },
        user => { isa => 'R2::Schema::User' },
    );

    sub update_members {
        my $self = shift;
        my ( $members, $user ) = validated_list( \@_, %spec );

        my %new_members = map { $_->{person_id} => $_ } @{$members};

        my $current_members = $self->members();

        while ( my ( undef, $membership ) = $current_members->next() ) {
            my $id = $membership->person_id();

            unless ( $new_members{$id} ) {
                $membership->delete( user => $user );
            }
            else {
                $membership->update(
                    position => $new_members{$id}->{position} // q{},
                );

                delete $new_members{$id};
            }
        }

        for my $new_member ( values %new_members ) {
            $self->add_member(
                %{$new_member},
                user => $user,
            );
        }
    }
}

# If these were regular subs they'd end up getting composed into the
# consuming classes, but they're just for internal use in the role
# block below.
my $_make_members_select = sub {
    my $class = shift;
    my $table = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('Person'), $table )
        ->from( $schema->table('Person'), $table );

    for my $pk ( @{ $class->Table()->primary_key() } ) {
        $select->where(
            $table->column( $pk->name() ),
            '=', Fey::Placeholder->new()
        );
    }

    $select->order_by( @{ R2::Schema::Person->DefaultOrderBy() } );

    return $select;
};

my $_make_member_count_select = sub {
    my $class = shift;
    my $table = shift;

    my $schema = R2::Schema->Schema();

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    $select->select( Fey::Literal::Function->new( 'COUNT', '*' ) )
        ->from($table);

    for my $col ( @{ $class->Table()->primary_key() } ) {
        $select->where(
            $table->column( $col->name() ),
            '=', Fey::Placeholder->new()
        );
    }

    return $select;
};

role {
    my $p     = shift;
    my %extra = @_;

    my $membership_table = $p->membership_table();
    my $membership_class
        = Fey::Meta::Class::Table->ClassForTable($membership_table);

    my $for_class = $extra{consumer}->name();

    my $members_select
        = $_make_members_select->( $for_class, $membership_table );

    method '_build_members' => sub {
        my $self = shift;

        my $dbh = $self->_dbh($members_select);

        return Fey::Object::Iterator::FromSelect->new(
            classes     => [ qw( R2::Schema::Person ), $membership_class ],
            dbh         => $dbh,
            select      => $members_select,
            bind_params => [ $self->pk_values_list() ],
        );
    };

    my $count_select
        = $_make_member_count_select->( $for_class, $membership_table );

    method '_build_member_count' => sub {
        my $self = shift;

        my $dbh = $self->_dbh($count_select);

        return $dbh->selectrow_arrayref( $count_select->sql($dbh), {},
            $self->pk_values_list() )->[0];
    };
};

1;
