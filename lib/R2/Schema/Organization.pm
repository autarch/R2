package R2::Schema::Organization;

use strict;
use warnings;

use R2::Schema;
use R2::Schema::Contact;
use R2::Schema::OrganizationMember;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with 'R2::Role::ActsAsContact'
    => { steps => [] };

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Organization') );

    has_one 'contact' =>
        ( table   => $schema->table('Contact'),
          handles => [ qw( email_addresses primary_email_address
                           websites
                           addresses primary_address
                           phone_numbers primary_phone_number
                           uri
                         ),
                       ( grep { ! __PACKAGE__->meta()->has_attribute($_) }
                         grep { $_ !~ /^(?:person|household|organization)$/ }
                         grep { ! /^_/ }
                         R2::Schema::Contact->meta()->get_attribute_list(),
                       )
                     ],
        );

    class_has 'DefaultOrderBy' =>
        ( is      => 'ro',
          isa     => 'ArrayRef',
          lazy    => 1,
          default =>
          sub { [ $schema->table('Organization')->column('name') ] },
        );

    with 'R2::Role::HasMembers' =>
        { membership_table => $schema->table('OrganizationMember') };
}

sub display_name
{
    return $_[0]->name();
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
