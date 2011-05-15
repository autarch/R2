package R2::Schema::Contact;

use strict;
use warnings;
use namespace::autoclean;

use Fey::Literal::String;
use Fey::Object::Iterator::FromArray;
use Fey::Object::Iterator::FromSelect;
use Fey::Placeholder;
use List::AllUtils qw( any first uniq );
use R2::Image;
use R2::CustomFieldType;
use R2::Schema;
use R2::Schema::Address;
use R2::Schema::ContactTag;
use R2::Schema::Email;
use R2::Schema::EmailAddress;
use R2::Schema::File;
use R2::Schema::MessagingProvider;
use R2::Schema::PhoneNumber;
use R2::Schema::Tag;
use R2::Schema::Website;
use R2::Types qw( ArrayRef Bool HashRef PosOrZeroInt Str );
use R2::Util qw( calm_to_studly string_is_empty );
use Sub::Name qw( subname );

# This needs to happen after the BEGIN phase to prevent all sorts of circular madness
UNITCHECK {
    require R2::Schema::Account;
    require R2::Schema::ContactNote;
    require R2::Schema::Donation;
    require R2::Schema::Household;
    require R2::Schema::Organization;
    require R2::Schema::Person;
}

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( pos_validated_list validated_list );

with 'R2::Role::Schema::DataValidator';
with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Contact') );

    has_one 'account' => (
        table   => $schema->table('Account'),
        handles => ['domain'],
    );

    for my $type (qw( person household organization )) {
        has_one $type => (
            table => $schema->table( ucfirst $type ),
            undef => 1,
        );

        has 'is_'
            . $type => (
            is      => 'ro',
            isa     => Bool,
            lazy    => 1,
            default => sub { $_[0]->contact_type() eq ucfirst $type ? 1 : 0 },
            init_arg => undef,
            );
    }

    has 'real_contact' => (
        is       => 'ro',
        does     => 'R2::Role::Schema::ActsAsContact',
        lazy     => 1,
        builder  => '_build_real_contact',
        init_arg => undef,
    );

    has_one '_file' => ( table => $schema->table('File') );

    has 'image' => (
        is      => 'ro',
        isa     => 'R2::Image|Undef',
        lazy    => 1,
        default => sub {
            my $file = $_[0]->_file
                or return;
            return R2::Image->new( file => $file );
        },
    );

    has_many 'email_addresses' => (
        table    => $schema->table('EmailAddress'),
        order_by => [
            $schema->table('EmailAddress')->column('is_preferred'),
            'DESC',
            $schema->table('EmailAddress')->column('email_address'),
            'ASC',
        ],
        cache => 1,
    );

    query email_address_count => (
        select      => __PACKAGE__->_CountContactsInTableSelect('EmailAddress'),
        bind_params => sub { $_[0]->contact_id() },
    );

    has_one 'preferred_email_address' => (
        table       => $schema->table('EmailAddress'),
        select      => __PACKAGE__->_PreferredThingSelect('EmailAddress'),
        bind_params => sub { $_[0]->contact_id() },
    );

    has_many 'addresses' => (
        table    => $schema->table('Address'),
        order_by => [
            $schema->table('Address')->column('is_preferred'),
            'DESC',
            $schema->table('Address')->column('country'),
            'ASC',
            $schema->table('Address')->column('region'),
            'ASC',
            $schema->table('Address')->column('city'),
            'ASC',
        ],
        cache => 1,
    );

    query address_count => (
        select      => __PACKAGE__->_CountContactsInTableSelect('Address'),
        bind_params => sub { $_[0]->contact_id() },
    );

    has_one 'preferred_address' => (
        table       => $schema->table('Address'),
        select      => __PACKAGE__->_PreferredThingSelect('Address'),
        bind_params => sub { $_[0]->contact_id() }
    );

    has_many 'phone_numbers' => (
        table    => $schema->table('PhoneNumber'),
        cache    => 1,
        order_by => [
            $schema->table('PhoneNumber')->column('is_preferred'),
            'DESC',
            $schema->table('PhoneNumber')->column('phone_number_type_id'),
            'ASC',
        ],
    );

    query phone_number_count => (
        select      => __PACKAGE__->_CountContactsInTableSelect('PhoneNumber'),
        bind_params => sub { $_[0]->contact_id() },
    );

    has_one 'preferred_phone_number' => (
        table       => $schema->table('PhoneNumber'),
        select      => __PACKAGE__->_PreferredThingSelect('PhoneNumber'),
        bind_params => sub { $_[0]->contact_id() }
    );

    has_many 'websites' => (
        table    => $schema->table('Website'),
        order_by => [
            $schema->table('Website')->column('label'),
            'ASC',
            $schema->table('Website')->column('uri'),
            'ASC',
        ],
        cache => 1,
    );

    query website_count => (
        select      => __PACKAGE__->_CountContactsInTableSelect('Website'),
        bind_params => sub { $_[0]->contact_id() },
    );

    has_many 'messaging_providers' => (
        table    => $schema->table('MessagingProvider'),
        cache    => 1,
        order_by => [
            $schema->table('MessagingProvider')->column('is_preferred'),
            'DESC',
            $schema->table('MessagingProvider')->column('messaging_provider_type_id'),
            'ASC',
        ],
    );

    has_one 'preferred_messaging_provider' => (
        table       => $schema->table('MessagingProvider'),
        select      => __PACKAGE__->_PreferredThingSelect('MessagingProvider'),
        bind_params => sub { $_[0]->contact_id() }
    );

    query messaging_provider_count => (
        select      => __PACKAGE__->_CountContactsInTableSelect('MessagingProvider'),
        bind_params => sub { $_[0]->contact_id() },
    );

    has_many 'donations' => (
        table => $schema->table('Donation'),
        fk    => (
            first {
                $_->has_column(
                    $schema->table('Donation')->column('contact_id') );
            }
            $schema->foreign_keys_between_tables(
                $schema->tables( 'Contact', 'Donation' )
            )
        ),
        order_by => [
            $schema->table('Donation')->column('donation_date'),
            'DESC',
            $schema->table('Donation')->column('amount'),
            'DESC',
        ],
        cache => 1,
    );

    query donation_count => (
        select      => __PACKAGE__->_CountContactsInTableSelect('Donation'),
        bind_params => sub { $_[0]->contact_id() },
    );

    has_many 'notes' => (
        table    => $schema->table('ContactNote'),
        order_by => [
            $schema->table('ContactNote')->column('note_datetime'),
            'DESC',
            $schema->table('ContactNote')->column('contact_note_type_id'),
            'ASC',
        ],
        cache => 1,
    );

    query note_count => (
        select      => __PACKAGE__->_CountContactsInTableSelect('ContactNote'),
        bind_params => sub { $_[0]->contact_id() },
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

    query email_count => (
        select      => __PACKAGE__->_CountContactsInTableSelect('ContactEmail'),
        bind_params => sub { $_[0]->contact_id() },
    );

    class_has '_EmailsSelect' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        builder => '_BuildEmailsSelect',
    );

    has emails => (
        is      => 'ro',
        isa     => 'Fey::Object::Iterator::FromSelect',
        lazy    => 1,
        builder => '_build_emails',
    );

    class_has '_ActivitiesWithParticipationsSelect' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        builder => '_BuildActivitiesWithParticipationsSelect',
    );

    has activities_with_participations => (
        is      => 'ro',
        isa     => 'Fey::Object::Iterator::FromSelect',
        lazy    => 1,
        builder => '_build_activities_with_participations',
    );

    has 'history' => (
        is      => 'ro',
        isa     => 'Fey::Object::Iterator::FromSelect',
        lazy    => 1,
        builder => '_build_history',
    );

    class_has '_HistorySelect' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        builder => '_BuildHistorySelect',
    );

    has last_modified_datetime => (
        is      => 'ro',
        isa     => 'DateTime',
        lazy    => 1,
        builder => '_build_last_modified_datetime',
    );

    class_has '_LastModifiedDateTimeSelect' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        builder => '_BuildLastModifiedDateTimeSelect',
    );

    has 'custom_fields' => (
        is      => 'ro',
        isa     => 'Fey::Object::Iterator::FromArray',
        lazy    => 1,
        builder => '_build_custom_fields',
    );

    has '_custom_field_values' => (
        traits  => ['Hash'],
        is      => 'ro',
        isa     => HashRef,
        lazy    => 1,
        builder => '_build_custom_field_values',
        handles => {
            custom_field_value      => 'get',
            _set_custom_field_value => 'set',
        },
        init_arg => undef,
        clearer  => '_clear_custom_field_values',
    );
}

with 'R2::Role::Schema::Serializes';

sub _CountContactsInTableSelect {
    my $class      = shift;
    my $table_name = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $table = $schema->table($table_name);

    my $count = Fey::Literal::Function->new(
        'COUNT',
        grep { $_->name() ne 'contact_id' } @{ $table->primary_key() },
    );

    #<<<
    $select
        ->select($count)
        ->from  ($table)
        ->where ( $table->column('contact_id'), '=', Fey::Placeholder->new() );
    #>>>
    return $select;
}

sub _PreferredThingSelect {
    my $class = shift;
    my $table_name = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $table = $schema->table($table_name);

    #<<<
    $select
        ->select($table)
        ->from  ($table)
        ->where ( $table->column('contact_id'), '=', Fey::Placeholder->new() )
        ->and   ( $table->column('is_preferred'),
                  '=', Fey::Literal::String->new('t') )
        ->limit (1);
    #>>>
    return $select;
}

sub _build_real_contact {
    my $self = shift;

    for my $type (qw( person household organization )) {
        my $is = 'is_' . $type;

        return $self->$type() if $self->$is();
    }

    die 'Cannot find a real contact for contact id: ' . $self->contact_id();
}

for my $pair (
    [ 'email_address',      'email_address' ],
    [ 'website',            'uri' ],
    [ 'messaging_provider', 'screen_name' ],
    [ 'phone_number',       'phone_number_type_id' ],
    [ 'address',            'address_type_id' ]
    ) {

    my $thing         = $pair->[0];
    my $existence_col = $pair->[1];

    my $plural = $thing . ( $thing =~ /s$/ ? 'es' : 's' );

    my $class = 'R2::Schema::' . calm_to_studly($thing);

    my $id_col = $thing . '_id';

    my $can_is_preferred = !!$class->can('is_preferred');

    my $count_method           = $thing . '_count';
    my $preferred_method       = 'preferred_' . $thing;
    my $clear_preferred_method = '_clear_preferred_' . $thing;

    my $method = 'update_or_add_' . $plural;

    my $sub = sub {
        my $self     = shift;
        my $existing = shift;
        my $new      = shift;
        my $user     = shift;

        if ($can_is_preferred) {
            if ( @{ $new || [] } && !$self->$count_method() ) {
                unless ( grep { $_->{is_preferred} } @{$new} ) {
                    $new->[0]->{is_preferred} = 1;
                }
            }
        }
        # XXX - if any update changes display_order, all display_order updates
        # should be collected and postponed, then done all at once in a safe
        # way.
        my $trans_sub = subname(
            'R2::Schema::Contact::_update_or_add-' . $thing => sub {
                for my $object ( $self->$plural()->all() ) {
                    my $updated_data = $existing->{ $object->$id_col() };

                    if ( string_is_empty( $updated_data->{$existence_col} ) )
                    {
                        $object->delete( user => $user );
                    }
                    else {
                        $object->update(
                            %{$updated_data},
                            user => $user,
                        );
                    }
                }

                for my $new_data ( @{$new} ) {
                    $class->insert(
                        %{$new_data},
                        contact_id => $self->contact_id(),
                        user       => $user
                    );
                }

                return unless $can_is_preferred;

                $self->$clear_preferred_method();

                return
                    if $self->$count_method() == 0
                        || $self->$preferred_method();

                die
                    "When calling $method, there must be one preferred $thing (or no $plural)";
            }
        );

        R2::Schema->RunInTransaction($trans_sub);

        return;
    };

    __PACKAGE__->meta()->add_method( $method => $sub );
}

sub add_donation {
    my $self = shift;

    return R2::Schema::Donation->insert(
        contact_id => $self->contact_id(),
        @_,
    );
}

sub add_note {
    my $self = shift;

    return R2::Schema::ContactNote->insert(
        contact_id => $self->contact_id(),
        @_,
    );
}

{
    my $select_base = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $sum = Fey::Literal::Function->new(
        'SUM',
        $schema->table('Donation')->column('amount')
    );

    #<<<
    $select_base
        ->select($sum)
        ->from  ( $schema->table('Donation') )
        ->where ( $schema->table('Donation')->column('contact_id'), '=',
                  Fey::Placeholder->new() );
    #>>>
    sub donation_total {
        my $self = shift;
        my ($date) = validated_list(
            \@_,
            since => { isa => 'DateTime', optional => 1 },
        );

        my $select = $select_base->clone();

        if ($date) {
            $select->where(
                $schema->table('Donation')->column('donation_date'),
                '>=',
                DateTime::Format::Pg->format_date($date)
            );
        }

        my $dbh = $self->_dbh($select);

        my $row = $dbh->selectrow_arrayref(
            $select->sql($dbh), {},
            $self->contact_id(), $select->bind_params()
        );

        # We need to numify the result or we may get a string like "1000.00"
        # instead of just 1000
        return $row ? $row->[0] + 0 : 0;
    }
}

sub has_custom_field_values_for_group {
    my $self = shift;
    my ($group) = pos_validated_list(
        \@_,
        { isa => 'R2::Schema::CustomFieldGroup' }
    );

    return any { $self->custom_field_value( $_->custom_field_id() ) }
    $group->custom_fields()->all();
}

{
    my $schema = R2::Schema->Schema();

    my %CountSelects;
    my %ValueSelects;

    for my $type ( R2::CustomFieldType->All() ) {
        my $type_table = $type->table();

        my $count_select = R2::Schema->SQLFactoryClass()->new_select();
        my $value_select = R2::Schema->SQLFactoryClass()->new_select();

        if ( $type_table->name() =~ /Select/ ) {
            my $value_table = $schema->table('CustomFieldSelectOption');

            my $count = Fey::Literal::Function->new(
                'COUNT',
                $value_table->column('value')
            );

            $count_select->select($count);

            #<<<
            $value_select
                ->select( $type_table->column('custom_field_id'),
                          $value_table->column('value') );
            #>>>
            for my $select ( $count_select, $value_select ) {
                #<<<
                $select
                    ->from  ( $type_table, $value_table )
                    ->order_by( $type_table->column('custom_field_id'),
                                $value_table->column('display_order') );
                #>>>
            }
        }
        else {
            my $count = Fey::Literal::Function->new(
                'COUNT',
                $type_table->column('value')
            );

            #<<<
            $count_select
                ->select($count)
                ->from  ($type_table);

            $value_select
                ->select( $type_table->columns( 'custom_field_id', 'value' ) )
                ->from  ($type_table);
            #>>>
        }

        $count_select->where(
            $type_table->column('custom_field_id'), '=',
            Fey::Placeholder->new()
        );

        for my $select ( $count_select, $value_select ) {
            $select->where(
                $type_table->column('contact_id'), '=',
                Fey::Placeholder->new()
            );
        }

        $CountSelects{ $type_table->name() } = $count_select;
        $ValueSelects{ $type_table->name() } = $value_select;
    }

    sub _build_custom_fields {
        my $self = shift;

        my @fields
            = map { $_->custom_fields()->all() }
            $self->account()->custom_field_groups()->all();

        my @populated;
        for my $field (@fields) {
            my $select = $CountSelects{ $field->type_table()->name() };

            my $dbh = $self->_dbh($select);

            my $row = $dbh->selectrow_arrayref(
                $select->sql($dbh), {},
                $field->custom_field_id(), $self->contact_id()
            );

            next unless $row && $row->[0];

            push @populated, $field;
        }

        return Fey::Object::Iterator::FromArray->new(
            classes => 'R2::Schema::CustomField',
            objects => \@populated,
        );
    }

    sub _build_custom_field_values {
        my $self = shift;

        my %fields = map { $_->custom_field_id() => $_ }
            map { $_->custom_fields()->all() }
            $self->account()->custom_field_groups()->all();

        my %values;
        for my $table ( uniq map { $_->type_table() } values %fields ) {
            my $select = $ValueSelects{ $table->name() };

            my $dbh = $self->_dbh($select);

            for my $row (
                @{
                    $dbh->selectall_arrayref(
                        $select->sql($dbh), {}, $self->contact_id()
                    )
                }
                ) {
                push @{ $values{ $row->[0] } }, $row->[1];
            }
        }

        my %return;
        for my $id ( keys %values ) {
            my $field = $fields{$id};

            $return{$id} = $field->value_object(
                contact_id      => $self->contact_id(),
                custom_field_id => $id,
                value           => (
                    @{ $values{$id} } == 1 ? $values{$id}[0] : $values{$id}
                ),
            );
        }

        return \%return;
    }
}

sub _build_tags {
    my $self = shift;

    my $select = $self->_TagsSelect();

    my $dbh = $self->_dbh($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes     => [qw( R2::Schema::Tag )],
        dbh         => $dbh,
        select      => $select,
        bind_params => [ $self->contact_id() ],
    );
}

sub _BuildTagsSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select
        ->select( $schema->tables('Tag') )
        ->from  ( $schema->tables( 'Tag', 'ContactTag' ) )
        ->where ( $schema->table('ContactTag')->column('contact_id'),
                  '=', Fey::Placeholder->new() )
        ->order_by( $schema->table('Tag')->column('tag') );
    #>>>
    return $select;
}

sub add_tags {
    my $self = shift;
    my ($tags) = validated_list(
        \@_,
        tags => ArrayRef [Str],
    );

    my @tag_ids;
    for my $tag_name ( @{$tags} ) {
        my %tag_p = (
            tag        => $tag_name,
            account_id => $self->account_id(),
        );

        my $tag;
        if ( $tag = R2::Schema::Tag->new(%tag_p) ) {
            next
                if R2::Schema::ContactTag->new(
                contact_id => $self->contact_id(),
                tag_id     => $tag->tag_id(),
                );

            push @tag_ids, $tag->tag_id();
        }
        else {
            $tag = R2::Schema::Tag->insert(%tag_p);

            push @tag_ids, $tag->tag_id();
        }
    }

    R2::Schema::ContactTag->insert_many(
        map { { contact_id => $self->contact_id(), tag_id => $_, } }
            @tag_ids )
        if @tag_ids;

    return;
}

sub _build_emails {
    my $self = shift;

    my $select = $self->_EmailsSelect();

    my $dbh = $self->_dbh($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes     => [qw( R2::Schema::Email )],
        dbh         => $dbh,
        select      => $select,
        bind_params => [ $self->contact_id() ],
    );
}

sub _BuildEmailsSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select
        ->select( $schema->tables('Email') )
        ->from  ( $schema->tables( 'Email', 'ContactEmail' ) )
        ->where ( $schema->table('ContactEmail')->column('contact_id'),
                  '=', Fey::Placeholder->new() )
        ->order_by( $schema->table('Email')->column('email_datetime'), 'DESC' );
    #>>>
    return $select;
}

sub _build_activities_with_participations {
    my $self = shift;

    my $select = $self->_ActivitiesWithParticipationsSelect();

    my $dbh = $self->_dbh($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes     => [qw( R2::Schema::Activity R2::Schema::ContactParticipation )],
        dbh         => $dbh,
        select      => $select,
        bind_params => [ $self->contact_id() ],
    );
}

sub _BuildActivitiesWithParticipationsSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select
        ->select( $schema->tables('Activity', 'ContactParticipation') )
        ->from  ( $schema->tables('Activity', 'ContactParticipation') )
        ->where ( $schema->table('ContactParticipation')->column('contact_id'),
                  '=', Fey::Placeholder->new() )
        ->order_by( $schema->table('ContactParticipation')->column('start_date'),
                    'DESC',
                    $schema->table('ContactParticipation')->column('end_date'),
                    'DESC',
                    $schema->table('Activity')->column('name'),
                    'ASC',
                  );
    #>>>
    return $select;
}

sub _build_history {
    my $self = shift;

    my $select = $self->_HistorySelect();

    my $dbh = $self->_dbh($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes     => [qw( R2::Schema::ContactHistory )],
        dbh         => $dbh,
        select      => $select,
        bind_params => [ $self->contact_id() ],
    );
}

sub _BuildHistorySelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select
        ->select( $schema->tables('ContactHistory') )
        ->from  ( $schema->tables( 'ContactHistory', 'ContactHistoryType' ) )
        ->where( $schema->table('ContactHistory')->column('contact_id'),
                 '=', Fey::Placeholder->new() )
        ->order_by( $schema->table('ContactHistory')->column('history_datetime'),
                    'DESC',
                    $schema->table('ContactHistoryType')->column('sort_order'),
                    'ASC' );
    #>>>
    return $select;
}

sub _build_last_modified_datetime {
    my $self = shift;

    my $select = $self->_LastModifiedDateTimeSelect();

    my $dbh = $self->_dbh($select);

    my $row = $dbh->selectrow_arrayref(
        $select->sql($dbh), {},
        $self->contact_id(),
    );

    return DateTime::Format::Pg->parse_datetime( $row->[0] );
}

sub _BuildLastModifiedDateTimeSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select
        ->select( $schema->table('ContactHistory')->column('history_datetime') )
        ->from  ( $schema->table('ContactHistory') )
        ->where( $schema->table('ContactHistory')->column('contact_id'),
                 '=', Fey::Placeholder->new() )
        ->order_by( $schema->table('ContactHistory')->column('history_datetime'),
                    'DESC' )
        ->limit(1);
    #>>>
    return $select;
}

sub _base_uri_path {
    my $self = shift;

    return
          $self->account()->_base_uri_path()
        . '/contact/'
        . $self->contact_id();
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
