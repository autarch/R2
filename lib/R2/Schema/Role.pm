package R2::Schema::Role;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Role') );

    for my $role (qw( Member Editor Admin )) {
        class_has $role => (
            is      => 'ro',
            isa     => 'R2::Schema::Role',
            lazy    => 1,
            default => sub { __PACKAGE__->_FindOrCreateRole($role) },
        );
    }

    class_has '_SelectAllSQL' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        lazy    => 1,
        builder => '_BuildSelectAllSQL',
    );
}

sub EnsureRequiredRolesExist {
    __PACKAGE__->Member();
    __PACKAGE__->Editor();
    __PACKAGE__->Admin();
}

sub _FindOrCreateRole {
    my $class = shift;
    my $name  = shift;

    my $role = eval { $class->new( name => $name ) };

    $role ||= $class->insert( name => $name );

    return $role;
}

sub All {
    my $class = shift;

    my $select = $class->_SelectAllSQL();

    my $dbh = $class->_dbh($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes => $class,
        dbh     => $dbh,
        select  => $select,
    );
}

sub _BuildSelectAllSQL {
    my $class = __PACKAGE__;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select
        ->select( $schema->table('Role') )
        ->from  ( $schema->tables('Role') )
        ->order_by( $schema->table('Role')->column('name') );
    #>>>
    return $select;
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
