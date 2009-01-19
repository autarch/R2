package R2::Schema::Role;

use strict;
use warnings;

use R2::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;


{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Role') );

    for my $role ( qw( Member Editor Admin ) )
    {
        class_has $role =>
            ( is      => 'ro',
              isa     => 'R2::Schema::Role',
              lazy    => 1,
              default => sub { __PACKAGE__->_CreateOrFindRole($role) },
            );
    }
}

sub _CreateOrFindRole
{
    my $class = shift;
    my $name  = shift;

    my $role = eval { $class->new( name => $name ) };

    $role ||= $class->insert( name => $name );

    return $role;
}

no Fey::ORM::Table;
no Moose;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__
