package R2::Schema::Household;

use strict;
use warnings;

use R2::Schema;
use R2::Schema::Contact;
use R2::Schema::HouseholdMember;

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( validatep );

with 'R2::Role::DVAAC';

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Household') );

    has_one 'contact' =>
        ( table   => $schema->table('Contact'),
          handles => [ qw( addresses phone_numbers ),
                       ( grep { ! __PACKAGE__->meta()->has_attribute($_) }
                         R2::Schema::Contact->meta()->get_attribute_list(),
                       )
                     ],
        );

    has 'members' =>
        ( is         => 'ro',
          isa        => 'Fey::Object::Iterator::Caching',
          lazy_build => 1,
        );

    class_has '_MembersSelect' =>
        ( is      => 'ro',
          isa     => 'Fey::SQL::Select',
          lazy    => 1,
          default => sub { __PACKAGE__->_BuildMembersSelect() },
        );

    class_has '_MemberInsert' =>
        ( is      => 'ro',
          isa     => 'Fey::SQL::Insert',
          lazy    => 1,
          default => sub { __PACKAGE__->_BuildMemberInsert() },
        );

    class_has 'DefaultOrderBy' =>
        ( is      => 'ro',
          isa     => 'ArrayRef',
          lazy    => 1,
          default =>
          sub { [ $schema->table('Household')->column('name') ] },
        );

    class_has '_ValidationSteps' =>
        ( is      => 'ro',
          isa     => 'ArrayRef[Str]',
          lazy    => 1,
          default => sub { [ ] },
        );
}

sub _build_friendly_name
{
    my $self = shift;

    return $self->name();
}

sub add_person
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
              $self->household_id(), $person_id, $position );
}

sub _build_members
{
    my $self = shift;

    my $select = $self->_MembersSelect();

    my $dbh = $self->_dbh($select);

    my $sth = $dbh->prepare( $select->sql($dbh) );

    return
        Fey::Object::Iterator::Caching->new
            ( classes     => [ qw( R2::Schema::Person R2::Schema::HouseholdMember ) ],
              handle      => $sth,
              bind_params => [ $self->household_id() ],
            );
}

sub _BuildMembersSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->tables( 'Person', 'HouseholdMember' ) )
           ->from( $schema->tables( 'Person', 'HouseholdMember' ) )
           ->where( $schema->table('HouseholdMember')->column('household_id'),
                    '=', Fey::Placeholder->new() )
           ->order_by( @{ R2::Schema::Person->DefaultOrderBy() } );

    return $select;
}

sub _BuildMemberInsert
{
    my $class = shift;

    my $insert = R2::Schema->SQLFactoryClass()->new_insert();

    my $schema = R2::Schema->Schema();

    my $ph = Fey::Placeholder->new();

    $insert->into( $schema->table('HouseholdMember')->columns( qw( household_id person_id position ) ) )
           ->values( household_id => $ph,
                     person_id    => $ph,
                     position     => $ph,
                   );

    return $insert;
}

no Fey::ORM::Table;
no Moose;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__
