package R2::Role::HasMembers;

use strict;
use warnings;

use Fey::Placeholder;
use R2::Exceptions qw( data_validation_error );
use R2::Schema;
use R2::Schema::Person;
use MooseX::Params::Validate qw( validatep );

use MooseX::Role::Parameterized;

parameter 'membership_table' =>
    ( isa      => 'Fey::Table',
      required => 1,
    );

role
{
    my $p = shift;

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

    method 'add_member' => sub
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

        $class->insert( $self->pk_values_hash(),
                        person_id => $person_id,
                        position  => $position,
                        user      => $user,
                      );
    };

    my $membership_table = $p->membership_table();
    my $membership_class = Fey::Meta::Class::Table->ClassForTable($membership_table);

    my $for_class = _find_r2_class();

    my $members_select = _make_members_select( $for_class, $membership_table );

    method '_build_members' => sub
    {
        my $self = shift;

        my $dbh = $self->_dbh($members_select);

        return
            Fey::Object::Iterator::Caching->new
                ( classes     => [ qw( R2::Schema::Person ), $membership_class ],
                  dbh         => $dbh,
                  select      => $members_select,
                  bind_params => [ $self->pk_values_list() ],
                );
    };

    my $count_select = _make_member_count_select( $for_class, $membership_table );

    method '_build_member_count' => sub
    {
        my $self = shift;

        my $dbh = $self->_dbh($count_select);

        return $dbh->selectrow_arrayref( $count_select->sql($dbh), {}, $self->pk_values_list() )->[0];
    };
};

# This is a really nasty hack that should be replaced by some proper
# API in MX::Role::Parameterized
sub _find_r2_class
{
    my $x = 0;
    while ( my $package = caller($x++) )
    {
        return $package if $package =~ /^R2::Schema::/;
    }

    die 'Cannot find the R2 class to which this role is being applied';
}

sub _make_members_select
{
    my $class = shift;
    my $table = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('Person'), $table )
           ->from( $schema->table('Person'), $table );

    for my $pk ( @{ $class->Table()->primary_key() } )
    {
        $select->where( $table->column( $pk->name() ),
                        '=', Fey::Placeholder->new() );
    }

    $select->order_by( @{ R2::Schema::Person->DefaultOrderBy() } );

    return $select;
}

sub _make_member_count_select
{
    my $class = shift;
    my $table = shift;

    my $schema = R2::Schema->Schema();

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    $select->select( Fey::Literal::Function->new( 'COUNT', '*' ) )
           ->from( $table );

    for my $col ( @{ $class->Table()->primary_key() } )
    {
        $select->where( $table->column( $col->name() ),
                        '=', Fey::Placeholder->new() );
    }

    return $select;
}

1;
