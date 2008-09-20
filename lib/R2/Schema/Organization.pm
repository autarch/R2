package R2::Schema::Organization;

use strict;
use warnings;

use R2::Schema::Contact;
use R2::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with 'R2::Role::ActsAsContact';

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Organization') );

    has_one 'contact' =>
        ( table   => $schema->table('Contact'),
          handles => [ grep { ! __PACKAGE__->meta()->has_attribute($_) }
                       R2::Schema::Contact->meta()->get_attribute_list(),
                     ],
        );

    class_has 'DefaultOrderBy' =>
        ( is      => 'ro',
          isa     => 'ArrayRef',
          lazy    => 1,
          default =>
          sub { [ $schema->table('Organization')->column('name') ] },
        );
}

sub _build_friendly_name
{
    my $self = shift;

    return $self->name();
}

no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__
