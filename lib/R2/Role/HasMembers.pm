package R2::Role::HasMembers;

use strict;
use warnings;

use R2::Exceptions qw( data_validation_error );
use R2::Schema::Person;
use MooseX::Params::Validate qw( validatep );

#use R2::Schema::HouseholdMember;
#use R2::Schema::OrganizationMember;

use Moose::Role;

requires '_MembershipTable';

has 'members' =>
    ( is         => 'ro',
      isa        => 'Fey::Object::Iterator::Caching',
      lazy_build => 1,
    );

has 'member_count' =>
    ( is         => 'ro',
      isa        => 'Int',
      lazy_build => 1,
    );


sub add_member
{
    my $self = shift;
    my ( $person_id, $position, $user ) =
        validatep( \@_,
                   person_id => { isa => 'Int' },
                   position  => { isa => 'Str', default => undef },
                   user      => { isa => 'R2::Schema::User' },
                 );

    my $person = R2::Schema::Person->new( person_id => $person_id );

    if ( $person->account_id() != $self->account_id() )
    {
        data_validation_error 'Cannot add a person from a different account.';
    }

    my $class = (ref $self) . 'Member';

    $class->insert( $self->pk_hash(),
                    person_id => $person_id,
                    position  => $position,
                    user      => $user,
                  );
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

sub _build_member_count
{
    my $self = shift;

    my $select = $self->_MemberCount();

    my $dbh = $self->_dbh($select);

    return $dbh->selectrow_arrayref( $select->sql($dbh), {}, $self->_pk_vals() )->[0];
}

# Can't have class attributes in a role yet
{
    my %MembersSelect;

    sub _MembersSelect
    {
        my $class = ref $_[0] || $_[0];

        return $MembersSelect{$class} ||= $class->_BuildMembersSelect();
    }
}

{
    my %MemberCount;

    sub _MemberCount
    {
        my $class = ref $_[0] || $_[0];

        return $MemberCount{$class} ||= $class->_BuildMemberCount();
    }
}

sub pk_hash
{
    my $self = shift;

    return
        ( map { $_ => $self->$_() }
          map { $_->name() }
          @{ $self->Table()->primary_key() }
        );
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

sub _BuildMemberCount
{
    my $class = shift;

    my $schema = R2::Schema->Schema();

    my $ph = Fey::Placeholder->new();

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    $select->select( Fey::Literal::Function->new( 'COUNT', '*' ) )
           ->from( $class->_MembershipTable() );

    for my $col ( @{ $class->Table()->primary_key() } )
    {
        $select->where( $class->_MembershipTable()->column( $col->name() ),
                        '=', $ph );
    }

    return $select;
}

no Moose::Role;

1;
