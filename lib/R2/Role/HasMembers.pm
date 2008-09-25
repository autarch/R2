package R2::Role::HasMembers;

use strict;
use warnings;

use R2::Schema::Person;

use Moose::Role;

requires '_MembershipTable';

has 'members' =>
    ( is         => 'ro',
      isa        => 'Fey::Object::Iterator::Caching',
      lazy_build => 1,
    );


sub add_member
{
    my $self = shift;
    my ( $person_id, $position ) =
        validatep( \@_,
                   person_id => { isa => 'Int' },
                   position  => { isa => 'Str', default => undef },
                 );

    my $insert = $self->_MemberInsert();

    my $dbh = $self->_dbh($insert);

    $dbh->do( $insert->sql($dbh), {},
              $self->pk_values(), $person_id, $position );
}

sub _build_members
{
    my $self = shift;

    my $select = $self->_MembersSelect();

    my $dbh = $self->_dbh($select);

    my $sth = $dbh->prepare( $select->sql($dbh) );

    my $membership_class =
        Fey::Meta::Class::Table->ClassForTable( $self->_MembershipTable() );

    return
        Fey::Object::Iterator::Caching->new
            ( classes     => [ qw( R2::Schema::Person ), $membership_class ],
              handle      => $sth,
              bind_params => [ $self->pk_values() ],
            );
}

# Can't have class attributes in a role yet
{
    my $MembersSelect;

    sub _MembersSelect
    {
        my $class = shift;

        return $MembersSelect ||= $class->_BuildMembersSelect();
    }
}

{
    my $MembersInsert;

    sub _MembersInsert
    {
        my $class = shift;

        return $MembersInsert ||= $class->_BuildMembersInsert();
    }
}

sub pk_values
{
    my $self = shift;

    return
        ( map { $self->$_() }
          map { $_->name() }
          @{ $self->Table()->primary_key() }
        );
}

sub _BuildMembersSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('Person'), $class->_MembershipTable() )
           ->from( $schema->table('Person'), $class->_MembershipTable() );

    for my $pk ( @{ $class->Table()->primary_key() } )
    {
        $select->where( $class->_MembershipTable->column( $pk->name() ),
                        '=', Fey::Placeholder->new() );
    }

    $select->order_by( @{ R2::Schema::Person->DefaultOrderBy() } );

    return $select;
}

sub _BuildMemberInsert
{
    my $class = shift;

    my $insert = R2::Schema->SQLFactoryClass()->new_insert();

    my $schema = R2::Schema->Schema();

    my $ph = Fey::Placeholder->new();

    my %pk_vals = map { $_->name() => $ph } @{ $class->Table()->primary_key() };

    $insert->into( $class->_MembershipTable()->columns() )
           ->values( %pk_vals,
                     person_id    => $ph,
                     position     => $ph,
                   );

    return $insert;
}

no Moose::Role;

1;
