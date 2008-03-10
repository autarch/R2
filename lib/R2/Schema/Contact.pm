package R2::Schema::Contact;

use strict;
use warnings;

use Fey::Literal::String;
use Fey::Placeholder;
use R2::Schema::Account;
use R2::Schema::Address;
use R2::Schema::PhoneNumber;
use R2::Schema;

# cannot load these because of circular dependency problems
#use R2::Schema::Household;
#use R2::Schema::Organization;
#use R2::Schema::Person;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Contact') );

    has_one( $schema->table('Account') );

    has_one 'person' =>
        ( table => $schema->table('Person'),
          undef => 1,
        );

    has_one 'organization' =>
        ( table    => $schema->table('Organization'),
          undef => 1,
        );

    has_one 'household' =>
        ( table => $schema->table('Household'),
          undef => 1,
        );

    has_many 'addresses' =>
        ( table => $schema->table('Address'),
          cache => 1,
        );

    has_one 'primary_address' =>
        ( table       => $schema->table('Address'),
          select      => __PACKAGE__->_PrimaryAddressSelect(),
          bind_params => sub { $_[0]->contact_id() }
        );

    has_many 'phone_numbers' =>
        ( table => $schema->table('PhoneNumber'),
          cache => 1,
        );

    has_one 'primary_phone_number' =>
        ( table       => $schema->table('PhoneNumber'),
          select      => __PACKAGE__->_PrimaryPhoneNumberSelect(),
          bind_params => sub { $_[0]->contact_id() }
        );
}

sub DelegatableMethods
{
    my $class = shift;

    return $class->meta()->get_attribute_list();
}

before 'update' => sub
{
    my $self = shift;
    my %p    = @_;

    my $person = $self->person()
        or return;

    die 'Cannot remove an email address for a user'
        if    exists $p{email_address}
           && ! defined $p{email_address}
           && $person->user();
};

sub _PrimaryAddressSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('Address') )
           ->from( $schema->table('Address') )
           ->where( $schema->table('Address')->column('contact_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $schema->table('Address')->column('is_primary'),
                  '=', Fey::Literal::String->new('t') )
           ->limit(1);

    return $select;
}

sub _PrimaryPhoneNumberSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('PhoneNumber') )
           ->from( $schema->table('PhoneNumber') )
           ->where( $schema->table('PhoneNumber')->column('contact_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $schema->table('PhoneNumber')->column('is_primary'),
                  '=', Fey::Literal::String->new('t') )
           ->limit(1);

    return $select;
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
