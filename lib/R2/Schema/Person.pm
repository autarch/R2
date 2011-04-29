package R2::Schema::Person;

use strict;
use warnings;
use namespace::autoclean;

use DateTime::Format::Natural;
use R2::Schema;
use R2::Util qw( string_is_empty );
use Scalar::Util qw( blessed );

use Fey::ORM::Table;
use MooseX::ClassAttribute;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    my $person_t = $schema->table('Person');

    has_table $person_t;

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

    require R2::Schema::Contact;

    has_one 'contact' => (
        table   => $schema->table('Contact'),
        handles => [
            qw(
                email_addresses
                primary_email_address
                websites
                messaging_providers
                addresses
                primary_address
                phone_numbers
                primary_phone_number
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

    has 'full_name' => (
        is      => 'ro',
        isa     => 'Str',
        lazy    => 1,
        builder => '_build_full_name',
    );
}

with 'R2::Role::Schema::Serializes';

with 'R2::Role::Schema::ActsAsContact' =>
    { steps => [qw( _require_some_name _valid_birth_date )] };

with 'R2::Role::Schema::HistoryRecorder';

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

    return {
        text     => 'A person requires either a first or last name.',
        category => 'invalid',
    };
}

sub _valid_birth_date {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if string_is_empty( $p->{birth_date} );

    my $dt;
    if ( blessed $p->{birth_date} ) {
        $dt = $p->{birth_date};
    }
    else {
        my $parser = DateTime::Format::Natural->new(
            time_zone => 'floating',
        );

        $dt = $parser->parse_datetime( $p->{birth_date} );

        return {
            field    => 'birth_date',
            text     => 'Birth date does not seem to be a valid date.',
            category => 'invalid',
            }
            unless $dt && !$parser->error();
    }

    return if DateTime->today( time_zone => 'floating' ) >= $dt;

    return {
        field    => 'birth_date',
        text     => 'Birth date cannot be in the future.',
        category => 'invalid',
    };
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

__PACKAGE__->meta()->make_immutable();

1;

__END__
