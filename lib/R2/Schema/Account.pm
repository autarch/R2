package R2::Schema::Account;

use strict;
use warnings;
use namespace::autoclean;

use Fey::Literal;
use Fey::Literal::Function;
use Fey::Object::Iterator::FromArray;
use Fey::Object::Iterator::FromSelect;
use Lingua::EN::Inflect qw( PL_N );
use List::AllUtils qw( any first );
use R2::Exceptions qw( error );
use R2::Schema::ActivityType;
use R2::Schema::AddressType;
use R2::Schema::ContactNoteType;
use R2::Schema::CustomFieldGroup;
use R2::Schema::Domain;
use R2::Schema::DonationSource;
use R2::Schema::DonationCampaign;
use R2::Schema::Household;
use R2::Schema::Organization;
use R2::Schema::PaymentType;
use R2::Schema::PhoneNumberType;
use R2::Schema::ParticipationType;
use R2::Schema::Person;
use R2::Schema::RelationshipType;
use R2::Schema::Role;
use R2::Schema::User;
use R2::Schema;
use R2::Types qw( ArrayRef Bool HashRef Int PosOrZeroInt );
use R2::Util qw( calm_to_studly string_is_empty );
use Sub::Name qw( subname );

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( validated_list );

with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Account') );

    has_one( $schema->table('Domain') );

    has_many 'donation_sources' => (
        table => $schema->table('DonationSource'),
        cache => 1,
        order_by =>
            [ $schema->table('DonationSource')->column('display_order') ],
    );

    has_many 'donation_campaigns' => (
        table => $schema->table('DonationCampaign'),
        cache => 1,
        order_by =>
            [ $schema->table('DonationCampaign')->column('display_order') ],
    );

    has_many 'payment_types' => (
        table => $schema->table('PaymentType'),
        cache => 1,
        order_by =>
            [ $schema->table('PaymentType')->column('display_order') ],
    );

    has_many 'address_types' => (
        table => $schema->table('AddressType'),
        cache => 1,
        order_by =>
            [ $schema->table('AddressType')->column('display_order') ],
    );

    has_many 'phone_number_types' => (
        table => $schema->table('PhoneNumberType'),
        cache => 1,
        order_by =>
            [ $schema->table('PhoneNumberType')->column('display_order') ],
    );

    has_many 'activity_types' => (
        table => $schema->table('ActivityType'),
        cache => 1,
        order_by =>
            [ $schema->table('ActivityType')->column('display_order') ],
    );

    has_many 'participation_types' => (
        table => $schema->table('ParticipationType'),
        cache => 1,
        order_by =>
            [ $schema->table('ParticipationType')->column('display_order') ],
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
            clearer => '_clear_custom_field_groups_for_' . $type
            );
    }

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

    class_has '_TagsSelect' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        builder => '_BuildTagsSelect',
    );

    has tags => (
        is      => 'ro',
        isa     => 'Fey::Object::Iterator::FromSelect',
        lazy    => 1,
        builder => '_build_tags',
    );

    class_has '_ActivityCountSelect' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        builder => '_BuildActivityCountSelect',
    );

    class_has '_ActivitySelect' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        builder => '_BuildActivitySelect',
    );

    has fiscal_year_start_date => (
        is      => 'ro',
        isa     => 'DateTime',
        lazy    => 1,
        builder => '_build_fiscal_year_start_date',
    );

    has 'made_a_note_contact_note_type' => (
        is      => 'ro',
        isa     => 'R2::Schema::ContactNoteType',
        lazy    => 1,
        builder => '_build_made_a_note_contact_note_type',
    );

    class_has '_UsersWithRolesSelect' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        builder => '_BuildUsersWithRolesSelect',
    );

    class_has '_TopDonorSelectBase' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        builder => '_BuildTopDonorSelectBase',
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

    R2::Schema::ActivityType->CreateDefaultsForAccount($self);

    R2::Schema::AddressType->CreateDefaultsForAccount($self);

    R2::Schema::ContactNoteType->CreateDefaultsForAccount($self);

    R2::Schema::DonationSource->CreateDefaultsForAccount($self);

    R2::Schema::DonationCampaign->CreateDefaultsForAccount($self);

    R2::Schema::PaymentType->CreateDefaultsForAccount($self);

    R2::Schema::PhoneNumberType->CreateDefaultsForAccount($self);

    R2::Schema::ParticipationType->CreateDefaultsForAccount($self);

    R2::Schema::RelationshipType->CreateDefaultsForAccount($self);
}

sub _build_fiscal_year_start_date {
    my $self = shift;

    my $today = DateTime->today( time_zone => 'floating' )
        ->truncate( to => 'month' );

    my $sub;
    if ( $today->month() < $self->fiscal_year_start_month() ) {
        $sub = 12 - ( $self->fiscal_year_start_month() - $today->month() );
    }
    else {
        $sub = $today->month() - $self->fiscal_year_start_month();
    }

    $today->subtract( months => $sub );

    return $today;
}

sub users_with_roles {
    my $self = shift;
    my ($include_disabled) = validated_list(
        \@_,
        include_disabled => { isa => Bool, default => 0 },
    );

    my $select = $self->_UsersWithRolesSelect();

    unless ($include_disabled) {
        $select = $select->clone();

        my $schema = R2::Schema->Schema();

        $select->where(
            $schema->table('User')->column('is_disabled'),
            '=', 0
        );
    }

    my $dbh = $self->_dbh($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes     => [qw( R2::Schema::User R2::Schema::Role )],
        dbh         => $dbh,
        select      => $select,
        bind_params => [ $self->account_id(), $select->bind_params() ],
    );
}

sub _BuildUsersWithRolesSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select
        ->select( $schema->tables( 'User', 'Role' ) )
        ->from  ( $schema->tables( 'User', 'Role' ) )
        ->where ( $schema->table('User')->column('account_id'),
                  '=', Fey::Placeholder->new() )
        ->order_by( $schema->table('User')->column('username') );
    #>>>
    return $select;
}

for my $pair (
    [ 'donation_source',    'name',        1 ],
    [ 'donation_campaign',  'name',        1 ],
    [ 'payment_type',       'name',        1 ],
    [ 'address_type',       'name',        1 ],
    [ 'phone_number_type',  'name',        1 ],
    [ 'contact_note_type',  'description', 1 ],
    [ 'custom_field_group', 'name' ],
    ) {

    my $thing         = $pair->[0];
    my $existence_col = $pair->[1];
    my $required      = $pair->[2];

    my $plural = $thing . 's';

    ( my $thing_name = $thing ) =~ s/_/ /g;

    my $class = 'R2::Schema::' . calm_to_studly($thing);

    my $id_col = $thing . '_id';

    my @clears = grep { __PACKAGE__->can($_) }
        map { '_clear_' . $plural . '_for_' . $_ }
        qw( person household organization );

    my $sub = sub {
        my $self     = shift;
        my $existing = shift;
        my $new      = shift;

        unless ( @{ $new || [] }
            || any { !string_is_empty( $_->{$existence_col} ) }
            values %{ $existing || {} } ) {

            return unless $required;

            error "You must have at least one $thing_name.";
        }

        my $trans_sub = subname(
            'R2::Schema::Account::_update_or_add-' . $thing => sub {
                for my $object ( $self->$plural()->all() ) {
                    my $updated_thing = $existing->{ $object->$id_col() };

                    if ( string_is_empty( $updated_thing->{$existence_col} ) )
                    {
                        next unless $object->is_deletable();

                        $object->delete();
                    }
                    else {
                        $object->update( %{$updated_thing} );
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

        R2::Schema->RunInTransaction($trans_sub);

        $self->$_() for @clears;
    };

    my $meth = 'update_or_add_' . $plural;

    __PACKAGE__->meta()->add_method( $meth => $sub );
}

sub _build_made_a_note_contact_note_type {
    my $self = shift;

    return R2::Schema::ContactNoteType->new(
        description => 'Made a note',
        account_id  => $self->account_id(),
    );
}

sub _build_tags {
    my $self = shift;

    my $select = $self->_TagsSelect();

    my $dbh = $self->_dbh($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes     => [qw( R2::Schema::Tag )],
        dbh         => $dbh,
        select      => $select,
        bind_params => [ $self->account_id() ],
    );
}

sub _BuildTagsSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $count = Fey::Literal::Function->new(
        'COUNT',
        $schema->table('ContactTag')->column('contact_id')
    );

    #<<<
    $select
        ->select( $schema->table('Tag'), $count )
        ->from  ( $schema->table('Tag'),
                  'left', $schema->tables('ContactTag') )
        ->where ( $schema->table('Tag')->column('account_id'),
                  '=', Fey::Placeholder->new() )
        ->order_by( $count, 'DESC',
                    $schema->table('Tag')->column('tag') )
        ->group_by( $schema->table('Tag')->columns() );
    #>>>
    return $select;
}

sub activity_count {
    my $self = shift;
    my ($include_archived) = validated_list(
        \@_,
        include_archived => { isa => Bool, default => 0 },
    );

    my $select = $self->_ActivityCountSelect()->clone();

    unless ($include_archived) {
        my $schema = R2::Schema->Schema();

        $select->where(
            $schema->table('Activity')->column('is_archived'),
            '=', 0
        );
    }

    my $dbh = $self->_dbh($select);

    my $row = $dbh->selectrow_arrayref(
        $select->sql($dbh), {},
        $self->account_id(), $select->bind_params()
    );

    return $row && $row->[0] ? $row->[0] : 0;
}

sub _BuildActivityCountSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $count = Fey::Literal::Function->new(
        'COUNT',
        $schema->table('Activity')->column('activity_id')
    );

    #<<<
    $select
        ->select($count)
        ->from  ( $schema->table('Activity') )
        ->where ( $schema->table('Activity')->column('account_id'),
                  '=', Fey::Placeholder->new() );
    #>>>
    return $select;
}

sub activities {
    my $self = shift;
    my ($include_archived) = validated_list(
        \@_,
        include_archived => { isa => Bool, default => 0 },
    );

    my $select = $self->_ActivitySelect()->clone();

    unless ($include_archived) {
        my $schema = R2::Schema->Schema();

        $select->where(
            $schema->table('Activity')->column('is_archived'),
            '=', 0
        );
    }

    return Fey::Object::Iterator::FromSelect->new(
        classes     => [qw( R2::Schema::Activity )],
        dbh         => $self->_dbh($select),
        select      => $select,
        bind_params => [ $self->account_id(), $select->bind_params() ],
    );
}

sub _BuildActivitySelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select
        ->select( $schema->table('Activity') )
        ->from  ( $schema->table('Activity') )
        ->where ( $schema->table('Activity')->column('account_id'),
                  '=', Fey::Placeholder->new() )
        ->order_by( $schema->table('Activity')->column('creation_datetime'),
                    'DESC' );
    #>>>
    return $select;
}

sub top_donors {
    my $self = shift;
    my ( $start_date, $end_date, $limit ) = validated_list(
        \@_,
        start_date => { isa => 'DateTime', optional => 1 },
        end_date   => { isa => 'DateTime', optional => 1 },
        limit      => { isa => Int,        default  => 20 },
    );

    my $select = $self->_TopDonorSelectBase()->clone();

    my $schema = R2::Schema->Schema();

    if ($start_date) {
        $select->where(
            $schema->table('Donation')->column('donation_date'),
            '>=', DateTime::Format::Pg->format_date($start_date)
        );
    }

    if ($end_date) {
        $select->where(
            $schema->table('Donation')->column('donation_date'),
            '<=', DateTime::Format::Pg->format_date($end_date)
        );
    }

    $select->limit($limit);

    my $dbh = $self->_dbh($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes     => [qw( R2::Schema::Contact )],
        dbh         => $dbh,
        select      => $select,
        bind_params => [ $self->account_id(), $select->bind_params() ],
    );
}

sub _BuildTopDonorSelectBase {
    my $class = shift;

    my $schema = R2::Schema->Schema();

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $sum = Fey::Literal::Function->new(
        'SUM',
        $schema->table('Donation')->column('amount')
    );

    my $fk = first {
        $_->has_column( $schema->table('Donation')->column('contact_id') );
    }
    $schema->foreign_keys_between_tables(
        $schema->tables( 'Contact', 'Donation' ) );

    #<<<
    $select
        ->select( $schema->table('Contact'), $sum )
        ->from( $schema->tables( 'Contact', 'Donation' ), $fk )
        ->where( $schema->table('Contact')->column('account_id'),
                 '=', Fey::Placeholder->new() )
        ->group_by( $schema->table('Contact')->columns() )
        ->order_by( $sum, 'DESC' );
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
        $select
            ->select($foreign_table)
            ->from  ( $schema->tables('Contact'), $foreign_table )
            ->where ( $schema->table('Contact')->column('account_id'),
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
        $select
            ->select($count)
            ->from  ( $schema->tables('Contact'), $foreign_table )
            ->where ( $schema->table('Contact')->column('account_id'),
                      '=', Fey::Placeholder->new() );
        #>>>
        my $build_count_meth = '_Build' . $type . 'CountSelect';
        __PACKAGE__->meta()->add_method( $build_count_meth => sub {$select} );

        query lc $type
            . '_count' => (
            select      => __PACKAGE__->$build_count_meth(),
            bind_params => sub { $_[0]->account_id() },
            );

        my $applies_meth = 'applies_to_' . lc $type;

        my $addr_types_attr = 'address_types_for_' . lc $type;
        has $addr_types_attr => (
            is       => 'ro',
            isa      => ArrayRef ['R2::Schema::AddressType'],
            init_arg => undef,
            lazy     => 1,
            default  => sub {
                [ grep { $_->$applies_meth() }
                        $_[0]->address_types()->all() ];
            },
            clearer => '_clear_' . $addr_types_attr,
        );

        my $phone_types_attr = 'phone_number_types_for_' . lc $type;
        has $phone_types_attr => (
            is       => 'ro',
            isa      => ArrayRef ['R2::Schema::PhoneNumberType'],
            init_arg => undef,
            lazy     => 1,
            default  => sub {
                [ grep { $_->$applies_meth() }
                        $_[0]->phone_number_types()->all() ];
            },
            clearer => '_clear_' . $phone_types_attr,
        );
    }

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $cfg_table = $schema->table('CustomFieldGroup');

    my $count = Fey::Literal::Function->new(
        'COUNT',
        @{ $cfg_table->primary_key() }
    );

    #<<<
    $select
        ->select($count)->from($cfg_table)
        ->where ( $cfg_table->column('account_id'), '=',
                  Fey::Placeholder->new() );
    #>>>
    query 'custom_field_group_count' => (
        select      => $select,
        bind_params => sub { $_[0]->account_id() },
    );
}

sub _base_uri_path {
    my $self = shift;

    return '/account/' . $self->account_id();
}

sub TO_JSON {
    my $self = shift;

    return { account_id => $self->account_id() };
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
