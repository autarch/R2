package R2::Schema::Contact;

use strict;
use warnings;

use Fey::Literal::String;
use Fey::Object::Iterator::FromSelect::Caching;
use Fey::Placeholder;
use List::AllUtils qw( any uniq );
use R2::Image;
use R2::CustomFieldType;
use R2::Schema;
use R2::Schema::Address;
use R2::Schema::EmailAddress;
use R2::Schema::File;
use R2::Schema::PhoneNumber;
use R2::Schema::Website;
use R2::Types;
use R2::Util qw( string_is_empty );

# cannot load these because of circular dependency problems
#use R2::Schema::Account;
#use R2::Schema::ContactNote;
#use R2::Schema::Donation;
#use R2::Schema::Household;
#use R2::Schema::Organization;
#use R2::Schema::Person;

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( pos_validated_list );

with 'R2::Role::Schema::DataValidator';
with 'R2::Role::Schema::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Contact') );

    has_one 'account' =>
        ( table   => $schema->table('Account'),
          handles => [ 'domain' ],
        );

    for my $type ( qw( person household organization ) )
    {
        has_one $type =>
            ( table => $schema->table( ucfirst $type ),
              undef => 1,
            );

        has 'is_' . $type =>
            ( is       => 'ro',
              isa      => 'Bool',
              lazy     => 1,
              default  => sub { $_[0]->contact_type() eq ucfirst $type ? 1 : 0 },
              init_arg => undef,
            );
    }

    has 'real_contact' =>
        ( is         => 'ro',
          does       => 'R2::Role::Schema::ActsAsContact',
          lazy_build => 1,
          init_arg   => undef,
        );

    has_one '_file' =>
        ( table => $schema->table('File') );

    has 'image' =>
        ( is      => 'ro',
          isa     => 'R2::Image|Undef',
          lazy    => 1,
          default => sub { my $file = $_[0]->_file
                               or return;
                           return R2::Image->new( file => $file ) },
        );

    has_many 'email_addresses' =>
        ( table    => $schema->table('EmailAddress'),
          order_by => [ $schema->table('EmailAddress')->column('is_preferred'),
                        'DESC',
                        $schema->table('EmailAddress')->column('email_address'),
                        'ASC',
                      ],
          cache    => 1,
        );

    has_one 'preferred_email_address' =>
        ( table       => $schema->table('EmailAddress'),
          select      => __PACKAGE__->_BuildPreferredEmailAddressSelect(),
          bind_params => sub { $_[0]->contact_id() }
        );

    has_many 'addresses' =>
        ( table    => $schema->table('Address'),
          order_by => [ $schema->table('Address')->column('is_preferred'),
                        'DESC',
                        $schema->table('Address')->column('iso_code'),
                        'ASC',
                        $schema->table('Address')->column('region'),
                        'ASC',
                        $schema->table('Address')->column('city'),
                        'ASC',
                      ],
          cache    => 1,
        );

    has_one 'preferred_address' =>
        ( table       => $schema->table('Address'),
          select      => __PACKAGE__->_BuildPreferredAddressSelect(),
          bind_params => sub { $_[0]->contact_id() }
        );

    has_many 'phone_numbers' =>
        ( table    => $schema->table('PhoneNumber'),
          cache    => 1,
          order_by => [ $schema->table('PhoneNumber')->column('is_preferred'),
                        'DESC',
                        $schema->table('PhoneNumber')->column('phone_number_type_id'),
                        'ASC',
                      ],
        );

    has_one 'preferred_phone_number' =>
        ( table       => $schema->table('PhoneNumber'),
          select      => __PACKAGE__->_BuildPreferredPhoneNumberSelect(),
          bind_params => sub { $_[0]->contact_id() }
        );

    has_many 'websites' =>
        ( table    => $schema->table('Website'),
          order_by => [ $schema->table('Website')->column('label'),
                        'ASC',
                        $schema->table('Website')->column('uri'),
                        'ASC',
                      ],
          cache    => 1,
        );

    has_many 'donations' =>
        ( table    => $schema->table('Donation'),
          order_by => [ $schema->table('Donation')->column('donation_date'),
                        'DESC',
                        $schema->table('Donation')->column('amount'),
                        'DESC',
                      ],
          cache    => 1,
        );

    has 'donation_count' =>
        ( metaclass   => 'FromSelect',
          is          => 'ro',
          isa         => 'R2.Type.PosOrZeroInt',
          lazy        => 1,
          select      => __PACKAGE__->_BuildDonationCountSelect(),
          bind_params => sub { $_[0]->contact_id() },
        );

    has_many 'notes' =>
        ( table    => $schema->table('ContactNote'),
          order_by => [ $schema->table('ContactNote')->column('note_datetime'),
                        'DESC',
                        $schema->table('ContactNote')->column('contact_note_type_id'),
                        'ASC',
                      ],
          cache    => 1,
        );

    has 'note_count' =>
        ( metaclass   => 'FromSelect',
          is          => 'ro',
          isa         => 'R2.Type.PosOrZeroInt',
          lazy        => 1,
          select      => __PACKAGE__->_BuildNoteCountSelect(),
          bind_params => sub { $_[0]->contact_id() },
        );

    class_has '_HistorySelect' =>
        ( is      => 'ro',
          isa     => 'Fey::SQL::Select',
          default => sub { __PACKAGE__->_BuildHistorySelect() },
        );

    has 'history' =>
        ( is         => 'ro',
          isa        => 'Fey::Object::Iterator::FromSelect::Caching',
          lazy_build => 1,
        );

    has '_custom_field_values' =>
        ( metaclass  => 'Collection::Hash',
          is         => 'ro',
          isa        => 'HashRef',
          lazy_build => 1,
          provides   => { 'get' => 'custom_field_value',
                          'set' => '_set_custom_field_value',
                        },
          init_arg   => undef,
        );
}

sub _BuildPreferredEmailAddressSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('EmailAddress') )
           ->from( $schema->table('EmailAddress') )
           ->where( $schema->table('EmailAddress')->column('contact_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $schema->table('EmailAddress')->column('is_preferred'),
                  '=', Fey::Literal::String->new('t') )
           ->limit(1);

    return $select;
}

sub _BuildPreferredAddressSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('Address') )
           ->from( $schema->table('Address') )
           ->where( $schema->table('Address')->column('contact_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $schema->table('Address')->column('is_preferred'),
                  '=', Fey::Literal::String->new('t') )
           ->limit(1);

    return $select;
}

sub _BuildPreferredPhoneNumberSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('PhoneNumber') )
           ->from( $schema->table('PhoneNumber') )
           ->where( $schema->table('PhoneNumber')->column('contact_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $schema->table('PhoneNumber')->column('is_preferred'),
                  '=', Fey::Literal::String->new('t') )
           ->limit(1);

    return $select;
}

sub _BuildDonationCountSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $count =
        Fey::Literal::Function->new( 'COUNT', $schema->table('Donation')->column('donation_id') );

    $select->select($count)
           ->from( $schema->tables( 'Donation' ) )
           ->where( $schema->table('Donation')->column('contact_id'),
                    '=', Fey::Placeholder->new() );

    return $select;
}

sub _BuildNoteCountSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $count =
        Fey::Literal::Function->new( 'COUNT', $schema->table('ContactNote')->column('contact_id') );

    $select->select($count)
           ->from( $schema->tables( 'ContactNote' ) )
           ->where( $schema->table('ContactNote')->column('contact_id'),
                    '=', Fey::Placeholder->new() );

    return $select;
}

sub _build_real_contact
{
    my $self = shift;

    for my $type ( qw( person household organization ) )
    {
        my $is = 'is_' . $type;

        return $self->$type() if $self->$is();
    }
}

sub add_donation
{
    my $self = shift;

    return
        R2::Schema::Donation->insert
            ( contact_id => $self->contact_id(),
              @_,
            );
}

sub add_email_address
{
    my $self = shift;

    return
        R2::Schema::EmailAddress->insert
            ( contact_id => $self->contact_id(),
              @_,
            );
}

sub add_website
{
    my $self = shift;

    return
        R2::Schema::Website->insert
            ( contact_id => $self->contact_id(),
              @_,
            );
}

sub add_address
{
    my $self = shift;

    return
        R2::Schema::Address->insert
            ( contact_id => $self->contact_id(),
              @_,
            );
}

sub add_phone_number
{
    my $self = shift;

    return
        R2::Schema::PhoneNumber->insert
            ( contact_id => $self->contact_id(),
              @_,
            );
}

sub add_note
{
    my $self = shift;

    return
        R2::Schema::ContactNote->insert
            ( contact_id => $self->contact_id(),
              @_,
            );
}

{
    my $select_base = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $sum = Fey::Literal::Function->new( 'SUM', $schema->table('Donation')->column('amount') );
    $select_base->select($sum)
                ->from( $schema->table('Donation') )
                ->where( $schema->table('Donation')->column('contact_id'), '=', Fey::Placeholder->new() );

    sub donations_total
    {
        my $self   = shift;
        my ($date) = pos_validated_list( \@_, { isa => 'DateTime', optional => 1 } );

        my $select = $select_base->clone();

        if ($date)
        {
            $select->where( $schema->table('Donation')->column('donation_date'),
                            '>=',
                            DateTime::Format::Pg->format_date($date) );
        }

        my $dbh = $self->_dbh($select);

        my $row = $dbh->selectrow_arrayref( $select->sql($dbh), {},
                                            $self->contact_id(), $select->bind_params() );

        return $row ? $row->[0] : 0;
    }
}

sub has_custom_field_values_for_group
{
    my $self = shift;
    my ($group) = pos_validated_list( \@_, { isa => 'R2::Schema::CustomFieldGroup' } );

    return
        any { $self->custom_field_value( $_->custom_field_id() ) }
        $group->custom_fields()->all();
}

{
    my $schema = R2::Schema->Schema();

    my %Selects;
    for my $type ( R2::CustomFieldType->All() )
    {
        my $type_table = $type->table();

        my $select = R2::Schema->SQLFactoryClass()->new_select();

        if ( $type_table->name() =~ /Select/ )
        {
            my $value_table = $schema->table('CustomFieldSelectOption');
            $select->select( $type_table->column('custom_field_id'), $value_table->column('value') )
                   ->from( $type_table, $value_table )
                   ->order_by( $type_table->column('custom_field_id'),
                               $value_table->column('display_order' ) );
        }
        else
        {
            $select->select( $type_table->columns( 'custom_field_id', 'value' ) )
                   ->from($type_table);
        }

        $select->where( $type_table->column('contact_id'), '=', Fey::Placeholder->new() );

        $Selects{ $type_table->name() } = $select;
    }

    sub _build__custom_field_values
    {
        my $self = shift;

        my %fields =
            map { $_->custom_field_id() => $_ }
            map { $_->custom_fields()->all() }
            $self->account()->custom_field_groups()->all();

        my %values;
        for my $table ( uniq map { $_->type_table() } values %fields )
        {
            my $select = $Selects{ $table->name() };

            my $dbh = $self->_dbh($select);

            for my $row ( @{ $dbh->selectall_arrayref( $select->sql($dbh), {}, $self->contact_id() ) } )
            {
                push @{ $values{ $row->[0] } }, $row->[1];
            }
        }

        my %return;
        for my $id ( keys %values )
        {
            my $field = $fields{$id};

            $return{$id} =
                $field->value_object
                    ( contact_id      => $self->contact_id(),
                      custom_field_id => $id,
                      value           =>
                          ( @{ $values{$id} } == 1 ? $values{$id}[0] : $values{$id} ),
                    );
        }

        return \%return;
    }
}

sub _build_history
{
    my $self = shift;

    my $select = $self->_HistorySelect();

    my $dbh = $self->_dbh($select);

    return
        Fey::Object::Iterator::FromSelect::Caching->new
            ( classes     =>
                  [ qw( R2::Schema::ContactHistory R2::Schema::ContactHistoryType ) ],
              dbh         => $dbh,
              select      => $select,
              bind_params => [ $self->contact_id() ],
            );
}

sub _BuildHistorySelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->tables( 'ContactHistory' ) )
           ->from( $schema->tables( 'ContactHistory', 'ContactHistoryType' ) )
           ->where( $schema->table('ContactHistory')->column('contact_id'),
                    '=', Fey::Placeholder->new() )
           ->order_by( $schema->table('ContactHistory')->column('history_datetime'),
                       'DESC',
                       $schema->table('ContactHistoryType')->column('sort_order'),
                       'ASC',
                     );

    return $select;
}

sub _base_uri_path
{
    my $self = shift;

    return $self->account()->_base_uri_path() . '/contact/' . $self->contact_id();
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
