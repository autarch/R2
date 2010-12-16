package R2::Schema::Account;

use strict;
use warnings;
use namespace::autoclean;

use Fey::Literal;
use Fey::Object::Iterator::FromArray;
use Fey::Object::Iterator::FromSelect::Caching;
use Lingua::EN::Inflect qw( PL_N );
use List::AllUtils qw( any );
use R2::Exceptions qw( error );
use R2::Schema::AccountCountry;
use R2::Schema::AccountMessagingProvider;
use R2::Schema::AccountUserRole;
use R2::Schema::AddressType;
use R2::Schema::ContactNoteType;
use R2::Schema::Country;
use R2::Schema::CustomFieldGroup;
use R2::Schema::Domain;
use R2::Schema::DonationSource;
use R2::Schema::DonationTarget;
use R2::Schema::Household;
use R2::Schema::Organization;
use R2::Schema::PaymentType;
use R2::Schema::PhoneNumberType;
use R2::Schema::Person;
use R2::Schema;
use R2::Types qw( Bool ArrayRef HashRef PosOrZeroInt );
use R2::Util qw( string_is_empty );
use Sub::Name qw( subname );

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( validated_list );

with 'R2::Role::Schema::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Account') );

    has_one( $schema->table('Domain') );

    has_many 'donation_sources' => (
        table    => $schema->table('DonationSource'),
        cache    => 1,
        order_by => [ $schema->table('DonationSource')->column('name') ],
    );

    has_many 'donation_targets' => (
        table    => $schema->table('DonationTarget'),
        cache    => 1,
        order_by => [ $schema->table('DonationTarget')->column('name') ],
    );

    has_many 'payment_types' => (
        table    => $schema->table('PaymentType'),
        cache    => 1,
        order_by => [ $schema->table('PaymentType')->column('name') ],
    );

    has_many 'address_types' => (
        table    => $schema->table('AddressType'),
        cache    => 1,
        order_by => [ $schema->table('AddressType')->column('name') ],
    );

    has_many 'phone_number_types' => (
        table    => $schema->table('PhoneNumberType'),
        cache    => 1,
        order_by => [ $schema->table('PhoneNumberType')->column('name') ],
    );

    has_many 'messaging_providers' => (
        table       => $schema->table('MessagingProvider'),
        cache       => 1,
        select      => __PACKAGE__->_BuildMessagingProvidersSelect(),
        bind_params => sub { $_[0]->account_id() },
    );

    has_many 'custom_field_groups' => (
        table => $schema->table('CustomFieldGroup'),
        cache => 1,
        order_by =>
            [ $schema->table('CustomFieldGroup')->column('display_order') ],
    );

    for my $type (qw( person household organization )) {
        my $meth = 'applies_to_' . $type;

        my $default = sub {
            my @groups
                = grep { $_->$meth() } $_[0]->custom_field_groups()->all();
            return Fey::Object::Iterator::FromArray->new(
                classes => 'R2::Schema::CustomFieldGroup',
                objects => \@groups,
            );
        };

        has 'custom_field_groups_for_'
            . $type => (
            is      => 'ro',
            isa     => 'Fey::Object::Iterator::FromArray',
            lazy    => 1,
            default => $default,
            );
    }

    has '_messaging_provider_id_hash' => (
        is       => 'ro',
        isa      => HashRef,
        lazy     => 1,
        builder  => '_build__messaging_provider_id_hash',
        init_arg => undef,
    );

    has_many 'contact_note_types' => (
        table    => $schema->table('ContactNoteType'),
        cache    => 1,
        order_by => [
            $schema->table('ContactNoteType')->column('is_system_defined'),
            'DESC',
            $schema->table('ContactNoteType')->column('description'),
            'ASC',
        ],
    );

    has 'made_a_note_contact_note_type' => (
        is      => 'ro',
        isa     => 'R2::Schema::ContactNoteType',
        lazy    => 1,
        builder => '_build_made_a_note_contact_note_type',
    );

    has 'countries' => (
        is       => 'ro',
        isa      => 'Fey::Object::Iterator::FromSelect::Caching',
        lazy     => 1,
        builder  => '_build_countries',
        init_arg => undef,
    );

    class_has '_CountriesSelect' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        default => sub { __PACKAGE__->_BuildCountriesSelect() },
    );

    class_has '_UsersWithRolesSelect' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        default => sub { __PACKAGE__->_BuildUsersWithRolesSelect() },
    );

    __PACKAGE__->_AddSQLMethods();
}

sub insert {
    my $class = shift;
    my %p     = @_;

    my $sub = subname(
        'R2::Schema::insert-initialize' => sub {
            my $account = $class->SUPER::insert(%p);

            $account->_initialize();

            return $account;
        }
    );

    return R2::Schema->RunInTransaction($sub);
}

sub _initialize {
    my $self = shift;

    R2::Schema::AddressType->CreateDefaultsForAccount($self);

    R2::Schema::ContactNoteType->CreateDefaultsForAccount($self);

    R2::Schema::DonationSource->CreateDefaultsForAccount($self);

    R2::Schema::DonationTarget->CreateDefaultsForAccount($self);

    R2::Schema::AccountMessagingProvider->CreateDefaultsForAccount($self);

    R2::Schema::PaymentType->CreateDefaultsForAccount($self);

    R2::Schema::PhoneNumberType->CreateDefaultsForAccount($self);

    for my $code (qw( us ca )) {
        $self->add_country(
            country => R2::Schema::Country->new( iso_code => $code ),
            is_default => ( $code eq 'us' ? 1 : 0 ),
        );
    }
}

sub add_user {
    my $self = shift;
    my ( $user, $role ) = validated_list(
        \@_,
        user => { isa => 'R2::Schema::User' },
        role => { isa => 'R2::Schema::Role' },
    );

    R2::Schema::AccountUserRole->insert(
        account_id => $self->account_id(),
        user_id    => $user->user_id(),
        role_id    => $role->role_id(),
    );
}

sub users_with_roles {
    my $self = shift;

    my $select = $self->_UsersWithRolesSelect();

    my $dbh = $self->_dbh($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes => [qw( R2::Schema::User R2::Schema::Role  )],
        dbh     => $dbh,
        select  => $select,
        bind_params => [ $self->account_id() ],
    );
}

sub add_country {
    my $self = shift;
    my ( $country, $is_default ) = validated_list(
        \@_,
        country    => { isa => 'R2::Schema::Country' },
        is_default => { isa => Bool },
    );

    R2::Schema::AccountCountry->insert(
        account_id => $self->account_id(),
        iso_code   => $country->iso_code(),
        is_default => $is_default,
    );
}

sub update_or_add_donation_sources {
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    $self->_update_or_add_things(
        $existing,
        $new,
        'donation_source',
        'name',
    );
}

sub update_or_add_donation_targets {
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    $self->_update_or_add_things(
        $existing,
        $new,
        'donation_target',
        'name',
    );
}

sub update_or_add_payment_types {
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    $self->_update_or_add_things(
        $existing,
        $new,
        'payment_type',
        'name',
    );
}

sub update_or_add_address_types {
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    $self->_update_or_add_things(
        $existing,
        $new,
        'address_type',
        'name',
    );
}

sub update_or_add_phone_number_types {
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    $self->_update_or_add_things(
        $existing,
        $new,
        'phone_number_type',
        'name',
    );
}

sub update_or_add_contact_note_types {
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    $self->_update_or_add_things(
        $existing,
        $new,
        'contact_note_type',
        'description',
    );
}

sub update_or_add_custom_field_groups {
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    my $order = $self->custom_field_group_count() + 1;
    for my $new ( @{$new} ) {
        $new->{display_order} = $order++;
    }

    $self->_update_or_add_things(
        $existing,
        $new,
        'custom_field_group',
        'name',
    );
}

sub _update_or_add_things {
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;
    my $thing    = shift;
    my $name_col = shift;

    my $id_col = $thing . '_id';
    ( my $thing_name = $thing ) =~ s/_/ /g;

    my $thing_pl = $thing . q{s};

    my $class = 'R2::Schema::' . ( join '', map {ucfirst} split /_/, $thing );

    unless ( @{ $new || [] }
        || any { !string_is_empty( $_->{$name_col} ) }
        values %{ $existing || {} } ) {
        error "You must have at least one $thing_name.";
    }

    my $sub = subname(
        'R2::Schema::_update_or_add_things-' . $thing => sub {
            for my $thing ( $self->$thing_pl()->all() ) {
                my $updated_thing = $existing->{ $thing->$id_col() };

                if ( string_is_empty( $updated_thing->{$name_col} ) ) {
                    next unless $thing->is_deletable();

                    $thing->delete();
                }
                else {
                    $thing->update( %{$updated_thing} );
                }
            }

            for my $new_thing ( @{$new} ) {
                $class->insert(
                    %{$new_thing},
                    account_id => $self->account_id(),
                );
            }
        }
    );

    R2::Schema->RunInTransaction($sub);

    return;
}

sub has_messaging_provider {
    my $self     = shift;
    my $provider = shift;

    return $self->_messaging_provider_id_hash()
        ->{ $provider->messaging_provider_id() };
}

sub _build_messaging_provider_id_hash {
    my $self = shift;

    return { map { $_->messaging_provider_id() => 1 }
            $self->messaging_providers()->all() };
}

sub _build_made_a_note_contact_note_type {
    my $self = shift;

    return R2::Schema::ContactNoteType->new(
        description => 'Made a note',
        account_id  => $self->account_id(),
    );
}

sub _build_countries {
    my $self = shift;

    my $select = $self->_CountriesSelect();

    my $dbh = $self->_dbh($select);

    return Fey::Object::Iterator::FromSelect::Caching->new(
        classes => [qw( R2::Schema::AccountCountry R2::Schema::Country  )],
        dbh     => $dbh,
        select  => $select,
        bind_params => [ $self->account_id() ],
    );
}

sub _BuildCountriesSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select->select( $schema->tables( 'AccountCountry', 'Country' ) )
           ->from  ( $schema->tables( 'AccountCountry', 'Country' ) )
           ->where ( $schema->table('AccountCountry')->column('account_id'),
                     '=', Fey::Placeholder->new() )
           ->order_by( $schema->table('AccountCountry')->column('is_default'),
                       'DESC',
                       $schema->table('Country')->column('name'),
                       'ASC',
                     );
    #>>>
    return $select;
}

sub _BuildMessagingProvidersSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select->select( $schema->tables('MessagingProvider') )
           ->from  ( $schema->tables( 'AccountMessagingProvider', 'MessagingProvider' ) )
           ->where ( $schema->table('AccountMessagingProvider')->column('account_id'),
                     '=', Fey::Placeholder->new() )
           ->order_by( $schema->table('MessagingProvider')->column('name'),
                       'ASC',
                     );
    #>>>
    return $select;
}

sub _BuildUsersWithRolesSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select->select( $schema->tables( 'User', 'Role' ) )
           ->from( $schema->tables( 'AccountUserRole', 'User' ) )
           ->from( $schema->tables( 'AccountUserRole', 'Role' ) )
           ->where( $schema->table('AccountUserRole')->column('account_id'),
                    '=', Fey::Placeholder->new() )
           ->order_by( $schema->table('User')->column('username') );
    #>>>
    return $select;
}

sub _AddSQLMethods {
    my $schema = R2::Schema->Schema();

    for my $type (qw( Person Household Organization )) {
        my $pl_type = PL_N($type);

        my $class = 'R2::Schema::' . $type;

        my $select = R2::Schema->SQLFactoryClass()->new_select();

        my $foreign_table = $schema->table($type);

        #<<<
        $select->select($foreign_table)
               ->from  ( $schema->tables('Contact'), $foreign_table )
               ->where( $schema->table('Contact')->column('account_id'),
                        '=', Fey::Placeholder->new() )
               ->order_by( @{ $class->DefaultOrderBy() } );
        #>>>
        has_many lc $pl_type => (
            table       => $foreign_table,
            select      => $select,
            bind_params => sub { $_[0]->account_id() },
        );

        $select = R2::Schema->SQLFactoryClass()->new_select();

        my $count = Fey::Literal::Function->new(
            'COUNT',
            @{ $foreign_table->primary_key() }
        );

        #<<<
        $select->select($count)
               ->from  ( $schema->tables('Contact'), $foreign_table )
               ->where( $schema->table('Contact')->column('account_id'),
                        '=', Fey::Placeholder->new() );
        #>>>
        my $build_count_meth = '_Build' . $type . 'CountSelect';
        __PACKAGE__->meta()->add_method( $build_count_meth => sub {$select} );

        has lc $type
            . '_count' => (
            metaclass   => 'FromSelect',
            is          => 'ro',
            isa         => PosOrZeroInt,
            lazy        => 1,
            select      => __PACKAGE__->$build_count_meth(),
            bind_params => sub { $_[0]->account_id() },
            );

        my $applies_meth = 'applies_to_' . lc $type;

        has lc $type . '_address_types' => (
            is      => 'ro',
            isa     => ArrayRef ['R2::Schema::AddressType'],
            lazy    => 1,
            default => sub {
                [ grep { $_->$applies_meth() }
                        $_[0]->address_types()->all() ];
            },
        );

        has lc $type . '_phone_number_types' => (
            is      => 'ro',
            isa     => ArrayRef ['R2::Schema::PhoneNumberType'],
            lazy    => 1,
            default => sub {
                [ grep { $_->$applies_meth() }
                        $_[0]->phone_number_types()->all() ];
            },
        );
    }

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $cfg_table = $schema->table('CustomFieldGroup');

    my $count = Fey::Literal::Function->new(
        'COUNT',
        @{ $cfg_table->primary_key() }
    );

    #<<<
    $select->select($count)->from($cfg_table)
           ->where( $cfg_table->column('account_id'), '=',
                    Fey::Placeholder->new() );
    #>>>
    has 'custom_field_group_count' => (
        metaclass   => 'FromSelect',
        is          => 'ro',
        isa         => PosOrZeroInt,
        lazy        => 1,
        select      => $select,
        bind_params => sub { $_[0]->account_id() },
    );
}

sub _base_uri_path {
    my $self = shift;

    return '/account/' . $self->account_id();
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
