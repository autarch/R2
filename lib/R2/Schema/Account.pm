package R2::Schema::Account;

use strict;
use warnings;

use R2::Schema::AccountCountry;
use R2::Schema::AccountUserRole;
use R2::Schema::AddressType;
use R2::Schema::Country;
use R2::Schema::Domain;
use R2::Schema::Fund;
use R2::Schema::MessagingProvider;
use R2::Schema::PhoneNumberType;
use R2::Schema;

use Fey::ORM::Table;
use MooseX::Params::Validate qw( validatep );

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Account') );

    has_one( $schema->table('Domain') );

    has_many 'funds' =>
        ( table    => $schema->table('Fund'),
          cache    => 1,
          order_by => [ $schema->table('Fund')->column('name') ],
        );

    has_many 'address_types' =>
        ( table    => $schema->table('AddressType'),
          cache    => 1,
          order_by => [ $schema->table('AddressType')->column('name') ],
        );

    has_many 'phone_number_types' =>
        ( table    => $schema->table('PhoneNumberType'),
          cache    => 1,
          order_by => [ $schema->table('PhoneNumberType')->column('name') ],
        );

    has_many 'messaging_providers' =>
        ( table    => $schema->table('MessagingProvider'),
          cache    => 1,
          order_by => [ $schema->table('MessagingProvider')->column('name') ],
        );

    has_many 'countries' =>
        ( table       => $schema->table('Country'),
          select      => __PACKAGE__->_CountriesSelect(),
          bind_params => sub { $_[0]->account_id() },
          cache       => 1,
        );

    has_many 'people' =>
        ( table       => $schema->table('Person'),
          select      => __PACKAGE__->_PeopleSelect(),
          bind_params => sub { $_[0]->account_id() },
        );
}


sub insert
{
    my $class = shift;
    my %p     = @_;

    my $sub = sub { my $account = $class->SUPER::insert(%p);

                    $account->_initialize();

                    return $account;
                  };

    return R2::Schema->RunInTransaction($sub);
};

sub _initialize
{
    my $self = shift;

    R2::Schema::Fund->CreateDefaultsForAccount($self);

    R2::Schema::AddressType->CreateDefaultsForAccount($self);

    R2::Schema::PhoneNumberType->CreateDefaultsForAccount($self);

    R2::Schema::MessagingProvider->CreateDefaultsForAccount($self);

    for my $code( qw( us ca ) )
    {
        $self->add_country( country => R2::Schema::Country->new( iso_code => $code ) );
    }
}

sub add_user
{
    my $self            = shift;
    my ( $user, $role ) =
        validatep( \@_,
                   user => { isa => 'R2::Schema::User' },
                   role => { isa => 'R2::Schema::Role' },
                 );

    R2::Schema::AccountUserRole->insert
        ( account_id => $self->account_id(),
          user_id    => $user->user_id(),
          role_id    => $role->role_id(),
        );
}

sub add_country
{
    my $self      = shift;
    my ($country) =
        validatep( \@_,
                   country => { isa => 'R2::Schema::Country' },
                 );

    R2::Schema::AccountCountry->insert
        ( account_id => $self->account_id(),
          iso_code   => $country->iso_code(),
        );
}

sub _CountriesSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('Country') )
           ->from( $schema->tables( 'AccountCountry', 'Country' ) )
           ->where( $schema->table('AccountCountry')->column('account_id'),
                    '=', Fey::Placeholder->new() )
           ->order_by( $schema->table('Country')->column('name') );

    return $select;
}

sub _PeopleSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('Person') )
           ->from( $schema->tables( 'Contact', 'Person' ) )
           ->where( $schema->table('Contact')->column('account_id'),
                    '=', Fey::Placeholder->new() )
           ->order_by( $schema->table('Person')->column('last_name'),
                       $schema->table('Person')->column('first_name'),
                       $schema->table('Person')->column('middle_name'),
                     );

    return $select;
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
