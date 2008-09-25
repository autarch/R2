package R2::Schema::Household;

use strict;
use warnings;

use R2::Schema;
use R2::Schema::Contact;
use R2::Schema::HouseholdMember;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with 'R2::Role::DVAAC', 'R2::Role::HasMembers';;

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

    class_has 'DefaultOrderBy' =>
        ( is      => 'ro',
          isa     => 'ArrayRef',
          lazy    => 1,
          default =>
          sub { [ $schema->table('Household')->column('name') ] },
        );

    my $mt = $schema->table('HouseholdMember');
    sub _MembershipTable { $mt }
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
