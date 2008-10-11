package R2::Schema::Account;

use strict;
use warnings;

use DateTime::Format::Pg;
use Fey::Literal;
use Fey::Object::Iterator::Caching;
use Lingua::EN::Inflect qw( PL_N );
use List::MoreUtils qw( any );
use R2::Exceptions qw( error );
use R2::Schema::AccountCountry;
use R2::Schema::AccountUserRole;
use R2::Schema::AddressType;
use R2::Schema::ContactHistoryType;
use R2::Schema::Country;
use R2::Schema::Domain;
use R2::Schema::DonationSource;
use R2::Schema::DonationTarget;
use R2::Schema::Household;
use R2::Schema::MessagingProvider;
use R2::Schema::Organization;
use R2::Schema::PaymentType;
use R2::Schema::PhoneNumberType;
use R2::Schema::Person;
use R2::Schema;
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( validatep );

with 'R2::Role::URIMaker';


{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Account') );

    transform 'creation_datetime' =>
        deflate { blessed $_[1] ? DateTime::Format::Pg->format_datetime( $_[1] ) : $_[1] },
        inflate { defined $_[1] ? DateTime::Format::Pg->parse_datetime( $_[1] ) : $_[1] };

    has_one( $schema->table('Domain') );

    has_many 'donation_sources' =>
        ( table    => $schema->table('DonationSource'),
          cache    => 1,
          order_by => [ $schema->table('DonationSource')->column('name') ],
        );

    has_many 'donation_targets' =>
        ( table    => $schema->table('DonationTarget'),
          cache    => 1,
          order_by => [ $schema->table('DonationTarget')->column('name') ],
        );

    has_many 'payment_types' =>
        ( table    => $schema->table('PaymentType'),
          cache    => 1,
          order_by => [ $schema->table('PaymentType')->column('name') ],
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

    has_many 'user_defined_contact_history_types' =>
        ( table       => $schema->table('ContactHistoryType'),
          cache       => 1,
          select      => __PACKAGE__->_BuildUserDefinedContactHistoryTypesSelect(),
          bind_params => sub { $_[0]->account_id(), 0 },
        );

    has 'countries' =>
        ( is         => 'ro',
          isa        => 'Fey::Object::Iterator::Caching',
          lazy_build => 1,
        );

    class_has '_CountriesSelect' =>
        ( is      => 'ro',
          isa     => 'Fey::SQL::Select',
          default => sub { __PACKAGE__->_BuildCountriesSelect() },
        );

    __PACKAGE__->_AddSQLMethods();
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
}

sub _initialize
{
    my $self = shift;

    R2::Schema::AddressType->CreateDefaultsForAccount($self);

    R2::Schema::ContactHistoryType->CreateDefaultsForAccount($self);

    R2::Schema::DonationSource->CreateDefaultsForAccount($self);

    R2::Schema::DonationTarget->CreateDefaultsForAccount($self);

    R2::Schema::MessagingProvider->CreateDefaultsForAccount($self);

    R2::Schema::PaymentType->CreateDefaultsForAccount($self);

    R2::Schema::PhoneNumberType->CreateDefaultsForAccount($self);

    for my $code ( qw( us ca ) )
    {
        $self->add_country
            ( country    => R2::Schema::Country->new( iso_code => $code ),
              is_default => ( $code eq 'us' ? 1 : 0 ),
            );
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
    my ( $country, $is_default ) =
        validatep( \@_,
                   country    => { isa => 'R2::Schema::Country' },
                   is_default => { isa => 'Bool' },
                 );

    R2::Schema::AccountCountry->insert
        ( account_id => $self->account_id(),
          iso_code   => $country->iso_code(),
          is_default => $is_default,
        );
}

sub update_or_add_donation_sources
{
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    unless ( @{ $new }
             || any { ! string_is_empty($_) } values %{ $existing } )
    {
        error 'You must have at least one donation source.';
    }

    my $sub =
        sub { for my $source ( $self->donation_sources()->all() )
              {
                  my $new_name = $existing->{ $source->donation_source_id() };

                  if ( string_is_empty($new_name) )
                  {
                      next unless $source->is_deleteable();

                      $source->delete();
                  }
                  else
                  {
                      $source->update( name => $new_name );
                  }
              }

              for my $name ( @{ $new } )
              {
                  R2::Schema::DonationSource->insert
                      ( name       => $name,
                        account_id => $self->account_id(),
                      );
              }
            };

    R2::Schema->RunInTransaction($sub);

    return;
}

sub update_or_add_donation_targets
{
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    unless ( @{ $new }
             || any { ! string_is_empty($_) } values %{ $existing } )
    {
        error 'You must have at least one donation target.';
    }

    my $sub =
        sub { for my $target ( $self->donation_targets()->all() )
              {
                  my $new_name = $existing->{ $target->donation_target_id() };

                  if ( string_is_empty($new_name) )
                  {
                      next unless $target->is_deleteable();

                      $target->delete();
                  }
                  else
                  {
                      $target->update( name => $new_name );
                  }
              }

              for my $name ( @{ $new } )
              {
                  R2::Schema::DonationTarget->insert
                      ( name       => $name,
                        account_id => $self->account_id(),
                      );
              }
            };

    R2::Schema->RunInTransaction($sub);

    return;
}

sub update_or_add_payment_types
{
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    unless ( @{ $new }
             || any { ! string_is_empty($_) } values %{ $existing } )
    {
        error 'You must have at least one payment type.';
    }

    my $sub =
        sub { for my $type ( $self->payment_types()->all() )
              {
                  my $new_name = $existing->{ $type->payment_type_id() };

                  if ( string_is_empty($new_name) )
                  {
                      next unless $type->is_deleteable();

                      $type->delete();
                  }
                  else
                  {
                      $type->update( name => $new_name );
                  }
              }

              for my $name ( @{ $new } )
              {
                  R2::Schema::PaymentType->insert
                      ( name       => $name,
                        account_id => $self->account_id(),
                      );
              }
            };

    R2::Schema->RunInTransaction($sub);

    return;
}

sub update_or_add_address_types
{
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    unless ( @{ $new }
             || any { ! string_is_empty( $_->{name} ) } values %{ $existing } )
    {
        error 'You must have at least one address type.';
    }

    my $sub =
        sub { for my $type ( $self->address_types()->all() )
              {
                  my $new_name = $existing->{ $type->address_type_id() }{name};

                  if ( string_is_empty($new_name) )
                  {
                      next unless $type->is_deleteable();

                      $type->delete();
                  }
                  else
                  {
                      $type->update( %{ $existing->{ $type->address_type_id() } } );
                  }
              }

              for my $type ( @{ $new } )
              {
                  R2::Schema::AddressType->insert
		      ( %{ $type },
			account_id => $self->account_id(),
		      );
              }
            };

    R2::Schema->RunInTransaction($sub);

    return;
}

sub update_or_add_phone_number_types
{
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    unless ( @{ $new }
             || any { ! string_is_empty( $_->{name} ) } values %{ $existing } )
    {
        error 'You must have at least one phone number type.';
    }

    my $sub =
        sub { for my $type ( $self->phone_number_types()->all() )
              {
                  my $new_name = $existing->{ $type->phone_number_type_id() }{name};

                  if ( string_is_empty($new_name) )
                  {
                      next unless $type->is_deleteable();

                      $type->delete();
                  }
                  else
                  {
                      $type->update( %{ $existing->{ $type->phone_number_type_id() } } );
                  }
              }

              for my $type ( @{ $new } )
              {
                  R2::Schema::PhoneNumberType->insert
		      ( %{ $type },
			account_id => $self->account_id(),
		      );
              }
            };

    R2::Schema->RunInTransaction($sub);

    return;
}

sub update_or_add_contact_history_types
{
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    unless ( @{ $new }
             || any { ! string_is_empty($_) } values %{ $existing } )
    {
        error 'You must have at least one contact history type.';
    }

    my $sub =
        sub { for my $type ( $self->user_defined_contact_history_types()->all() )
              {
                  my $new_name = $existing->{ $type->contact_history_type_id() };

                  if ( string_is_empty($new_name) )
                  {
                      next unless $type->is_deleteable();

                      $type->delete();
                  }
                  else
                  {
                      $type->update( description =>
                                     $existing->{ $type->contact_history_type_id() } );
                  }
              }

              for my $type ( @{ $new } )
              {
                  R2::Schema::ContactHistoryType->insert
		      ( description => $type,
			account_id  => $self->account_id(),
		      );
              }
            };

    R2::Schema->RunInTransaction($sub);

    return;
}

sub _BuildUserDefinedContactHistoryTypesSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->tables( 'ContactHistoryType' ) )
           ->from( $schema->tables( 'ContactHistoryType' ) )
           ->where( $schema->table('ContactHistoryType')->column('account_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $schema->table('ContactHistoryType')->column('is_system_defined'),
                  '=', Fey::Placeholder->new() )
           ->order_by( $schema->table('ContactHistoryType')->column('description') );

    return $select;
}

sub _build_countries
{
    my $self = shift;

    my $select = $self->_CountriesSelect();

    my $dbh = $self->_dbh($select);

    my $sth = $dbh->prepare( $select->sql($dbh) );

    return
        Fey::Object::Iterator::Caching->new
            ( classes     => [ qw( R2::Schema::AccountCountry R2::Schema::Country  ) ],
              handle      => $sth,
              bind_params => [ $self->account_id() ],
            );
}

sub _BuildCountriesSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->tables( 'AccountCountry', 'Country' ) )
           ->from( $schema->tables( 'AccountCountry', 'Country' ) )
           ->where( $schema->table('AccountCountry')->column('account_id'),
                    '=', Fey::Placeholder->new() )
           ->order_by( $schema->table('AccountCountry')->column('is_default'),
                       'DESC',
                       $schema->table('Country')->column('name'),
                       'ASC',
                     );

    return $select;
}

sub _AddSQLMethods
{
    my $schema = R2::Schema->Schema();

    for my $type ( qw( Person Household Organization ) )
    {
        my $pl_type = PL_N($type);

        my $class = 'R2::Schema::' . $type;

        my $select = R2::Schema->SQLFactoryClass()->new_select();

        my $foreign_table = $schema->table($type);

        $select->select($foreign_table)
               ->from( $schema->tables('Contact'), $foreign_table )
               ->where( $schema->table('Contact')->column('account_id'),
                        '=', Fey::Placeholder->new() )
               ->order_by( @{ $class->DefaultOrderBy() } );

        has_many lc $pl_type =>
            ( table       => $foreign_table,
              select      => $select,
              bind_params => sub { $_[0]->account_id() },
            );

        $select = R2::Schema->SQLFactoryClass()->new_select();

        my $count =
            Fey::Literal::Function->new
                ( 'COUNT', @{ $foreign_table->primary_key() } );

        $select->select($count)
               ->from( $schema->tables('Contact'), $foreign_table )
               ->where( $schema->table('Contact')->column('account_id'),
                        '=', Fey::Placeholder->new() );

        my $build_count_meth = '_Build' . $type . 'CountSelect';
        __PACKAGE__->meta()->add_method
            ( $build_count_meth => sub { $select } );

        has lc $type . '_count' =>
            ( metaclass   => 'FromSelect',
              is          => 'ro',
              isa         => 'R2::Type::PosOrZeroInt',
              lazy        => 1,
              select      => __PACKAGE__->$build_count_meth(),
              bind_params => sub { $_[0]->account_id() },
            );

        my $applies_meth = 'applies_to_' . lc $type;

        has lc $type . '_address_types' =>
            ( is      => 'ro',
              isa     => 'ArrayRef[R2::Schema::AddressType]',
              lazy    => 1,
              default => sub { [ grep { $_->$applies_meth() }
                                 $_[0]->address_types()->all() ] },
            );

        has lc $type . '_phone_number_types' =>
            ( is      => 'ro',
              isa     => 'ArrayRef[R2::Schema::PhoneNumberType]',
              lazy    => 1,
              default => sub { [ grep { $_->$applies_meth() }
                                 $_[0]->phone_number_types()->all() ] },
            );
    }
}

sub _base_uri_path
{
    my $self = shift;

    return '/account/' . $self->account_id();
}

no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__
