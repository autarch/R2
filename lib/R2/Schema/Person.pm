package R2::Schema::Person;

use strict;
use warnings;

use DateTime::Format::Strptime;
use R2::Schema;
use R2::Schema::Contact;
use R2::Schema::PersonMessagingProvider;
use R2::Util qw( string_is_empty );
use Scalar::Util qw( blessed );

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with 'R2::Role::Schema::ActsAsContact' =>
    { steps => [qw( _require_some_name _valid_birth_date )] };

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    my $person_t = $schema->table('Person');

    has_table $person_t;

    has_one 'contact' => (
        table   => $schema->table('Contact'),
        handles => [
            qw( email_addresses primary_email_address
                websites
                addresses primary_address
                phone_numbers primary_phone_number
                uri
                has_custom_field_values_for_group
                custom_field_value
                ),
            (
                grep     { !__PACKAGE__->meta()->has_attribute($_) }
                    grep { $_ !~ /^(?:person|household|organization)$/ }
                    grep { !/^_/ }
                    R2::Schema::Contact->meta()->get_attribute_list(),
            )
        ],
    );

    has_one 'user' => (
        table => $schema->table('User'),
        undef => 1,
    );

    # XXX - this'd be nicer if it selected the messaging provider in
    # the same query
    has_many 'messaging' => (
        table       => $schema->table('PersonMessagingProvider'),
        cache       => 1,
        select      => __PACKAGE__->_MessagingSelect(),
        bind_params => sub { $_[0]->person_id() },
    );

    has 'full_name' => (
        is         => 'ro',
        isa        => 'Str',
        lazy_build => 1,
    );

    class_has 'GenderValues' => (
        is         => 'ro',
        isa        => 'ArrayRef',
        lazy_build => 1,
    );

    class_has 'DefaultOrderBy' => (
        is      => 'ro',
        isa     => 'ArrayRef',
        lazy    => 1,
        default => sub {
            [
                $schema->table('Person')->column('last_name'),
                $schema->table('Person')->column('first_name'),
                $schema->table('Person')->column('middle_name'),
            ];
        },
    );
}

sub _build_GenderValues {
    my $class = shift;

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    my $sth = $dbh->column_info( '', '', 'Person', 'gender' );

    my $col_info = $sth->fetchall_arrayref( {} )->[0];

    return $col_info->{pg_enum_values} || [];
}

sub _require_some_name {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    if ($is_insert) {
        return
            unless string_is_empty( $p->{first_name} )
                && string_is_empty( $p->{last_name} );
    }
    else {
        return
            unless exists $p->{first_name}
                && exists $p->{last_name}
                && string_is_empty( $p->{first_name} )
                && string_is_empty( $p->{last_name} );

    }

    return { message => 'A person requires either a first or last name.' };
}

sub _valid_birth_date {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    my $format = delete $p->{date_format};

    return if string_is_empty( $p->{birth_date} );

    my $dt;
    if ( blessed $p->{birth_date} ) {
        $dt = $p->{birth_date};
    }
    else {
        my $parser = DateTime::Format::Strptime->new(
            pattern   => $format,
            time_zone => 'floating',
        );

        $dt = $parser->parse_datetime( $p->{birth_date} );

        return {
            field   => 'birth_date',
            message => 'Birth date does not seem to be a valid date.',
            }
            unless $dt;
    }

    return if DateTime->today( time_zone => 'floating' ) >= $dt;

    return {
        field   => 'birth_date',
        message => 'Birth date cannot be in the future.',
    };
}

sub _MessagingSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('PersonMessagingProvider') )
        ->from(
        $schema->tables( 'PersonMessagingProvider', 'MessagingProvider' ) )
        ->where(
        $schema->table('PersonMessagingProvider')->column('person_id'),
        '=', Fey::Placeholder->new()
        )
        ->order_by( $schema->table('MessagingProvider')->column('name'),
        'ASC' );

    return $select;
}

sub display_name {
    return $_[0]->full_name();
}

sub _build_friendly_name {
    my $self = shift;

    return $self->first_name();
}

sub _build_full_name {
    my $self = shift;

    return (
        join ' ',
        grep    { !string_is_empty($_) }
            map { $self->$_() }
            qw( salutation first_name middle_name last_name suffix )
    );
}

no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__
