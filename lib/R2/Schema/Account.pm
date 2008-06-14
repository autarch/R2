package R2::Schema::Account;

use strict;
use warnings;

use DateTime::Format::Pg;
use R2::Schema::AccountCountry;
use R2::Schema::AccountUserRole;
use R2::Schema::AddressType;
use R2::Schema::Country;
use R2::Schema::Domain;
use R2::Schema::DonationSource;
use R2::Schema::DonationTarget;
use R2::Schema::MessagingProvider;
use R2::Schema::PaymentType;
use R2::Schema::PhoneNumberType;
use R2::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( validatep );

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

    for my $type ( qw( person household organization ) )
    {
        my $applies_meth = 'applies_to_' . $type;

        has $type . '_address_types' =>
            ( is      => 'ro',
              isa     => 'ArrayRef[R2::Schema::AddressType]',
              lazy    => 1,
              default => sub { [ grep { $_->$applies_meth() }
                                 $_[0]->address_types()->all() ] },
            );

        has $type . '_phone_number_types' =>
            ( is      => 'ro',
              isa     => 'ArrayRef[R2::Schema::PhoneNumberType]',
              lazy    => 1,
              default => sub { [ grep { $_->$applies_meth() }
                                 $_[0]->phone_number_types()->all() ] },
            );
    }

    has_many 'messaging_providers' =>
        ( table    => $schema->table('MessagingProvider'),
          cache    => 1,
          order_by => [ $schema->table('MessagingProvider')->column('name') ],
        );

    has_many 'countries' =>
        ( table       => $schema->table('Country'),
          select      => __PACKAGE__->_BuildCountriesSelect(),
          bind_params => sub { $_[0]->account_id() },
          cache       => 1,
        );

    has_many 'people' =>
        ( table       => $schema->table('Person'),
          select      => __PACKAGE__->_BuildPeopleSelect(),
          bind_params => sub { $_[0]->account_id() },
        );

    class_has '_DonationSourcesDelete' =>
        ( is      => 'ro',
          isa     => 'Fey::SQL::Delete',
          lazy    => 1,
          default => sub { __PACKAGE__->_BuildDonationSourcesDelete() },
        );

    class_has '_DonationTargetsDelete' =>
        ( is      => 'ro',
          isa     => 'Fey::SQL::Delete',
          lazy    => 1,
          default => sub { __PACKAGE__->_BuildDonationTargetsDelete() },
        );

    class_has '_PaymentTypesDelete' =>
        ( is      => 'ro',
          isa     => 'Fey::SQL::Delete',
          lazy    => 1,
          default => sub { __PACKAGE__->_BuildPaymentTypesDelete() },
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
}

sub _initialize
{
    my $self = shift;

    R2::Schema::DonationSource->CreateDefaultsForAccount($self);

    R2::Schema::DonationTarget->CreateDefaultsForAccount($self);

    R2::Schema::PaymentType->CreateDefaultsForAccount($self);

    R2::Schema::AddressType->CreateDefaultsForAccount($self);

    R2::Schema::PhoneNumberType->CreateDefaultsForAccount($self);

    R2::Schema::MessagingProvider->CreateDefaultsForAccount($self);

    for my $code ( qw( us ca ) )
    {
        $self->add_country( country    => R2::Schema::Country->new( iso_code => $code ),
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

sub replace_donation_sources
{
    my $self    = shift;
    my @sources = @_;

    my $sub = sub { $self->_delete_all_donation_sources();

                    for my $name (@sources)
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

sub _delete_all_donation_sources
{
    my $self = shift;

    my $delete = $self->_DonationSourcesDelete();

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    $dbh->do( $delete->sql($dbh), {}, $self->account_id() );

    $self->_clear_donation_sources();
}

sub _BuildDonationSourcesDelete
{
    my $class = shift;

    my $delete = R2::Schema->SQLFactoryClass()->new_delete();

    my $schema = R2::Schema->Schema();

    $delete->from( $schema->table('DonationSource') )
           ->where( $schema->table('DonationSource')->column('account_id'),
                    '=', Fey::Placeholder->new() );

    return $delete;
}

sub replace_donation_targets
{
    my $self    = shift;
    my @targets = @_;

    my $sub = sub { $self->_delete_all_donation_targets();

                    for my $name (@targets)
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

sub _delete_all_donation_targets
{
    my $self = shift;

    my $delete = $self->_DonationTargetsDelete();

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    $dbh->do( $delete->sql($dbh), {}, $self->account_id() );

    $self->_clear_donation_targets();
}

sub _BuildDonationTargetsDelete
{
    my $class = shift;

    my $delete = R2::Schema->SQLFactoryClass()->new_delete();

    my $schema = R2::Schema->Schema();

    $delete->from( $schema->table('DonationTarget') )
           ->where( $schema->table('DonationTarget')->column('account_id'),
                    '=', Fey::Placeholder->new() );

    return $delete;
}

sub replace_payment_types
{
    my $self    = shift;
    my @targets = @_;

    my $sub = sub { $self->_delete_all_payment_types();

                    for my $name (@targets)
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

sub _delete_all_payment_types
{
    my $self = shift;

    my $delete = $self->_PaymentTypesDelete();

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    $dbh->do( $delete->sql($dbh), {}, $self->account_id() );

    $self->_clear_payment_types();
}

sub _BuildPaymentTypesDelete
{
    my $class = shift;

    my $delete = R2::Schema->SQLFactoryClass()->new_delete();

    my $schema = R2::Schema->Schema();

    $delete->from( $schema->table('PaymentType') )
           ->where( $schema->table('PaymentType')->column('account_id'),
                    '=', Fey::Placeholder->new() );

    return $delete;
}

sub _BuildCountriesSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('Country') )
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

sub _BuildPeopleSelect
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
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__
