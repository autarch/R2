package R2::Request;

use strict;
use warnings;
use namespace::autoclean;

use DateTime::Format::Natural;
use List::AllUtils qw( true );
use R2::Util qw( string_is_empty );

use Moose::Role;

with 'Catalyst::TraitFor::Request::REST::ForBrowsers';

sub person_params {
    my $self = shift;

    my %person = $self->_params_for_classes(
        [ 'R2::Schema::Person', 'R2::Schema::Contact' ] );

    my $params = $self->params();

    $person{gender} = $params->{gender_text}
        unless string_is_empty( $params->{gender_text} );

    return %person;
}

sub household_params {
    my $self = shift;

    return $self->_params_for_classes(
        [ 'R2::Schema::Household', 'R2::Schema::Contact' ] );
}

sub organization_params {
    my $self = shift;

    return $self->_params_for_classes(
        [ 'R2::Schema::Organization', 'R2::Schema::Contact' ] );
}

sub account_params {
    my $self = shift;

    return $self->_params_for_classes( ['R2::Schema::Account'] );
}

my @objects = (
    {
        type          => 'EmailAddress',
        filter        => sub { string_is_empty( $_[0]->{email_address} ) },
        has_preferred => 1,
    }, {
        type   => 'Website',
        field  => 'uri',
        filter => sub { string_is_empty( $_[0]->{uri} ) },
    }, {
        type          => 'MessagingProvider',
        field         => 'screen_name',
        filter        => sub { string_is_empty( $_[0]->{screen_name} ) },
        has_preferred => 1,
    }, {
        type  => 'Address',
        field => 'address_type_id',
        filter =>    # If it just has a type we ignore it.
            sub {
            ( true { !string_is_empty($_) } values %{ $_[0] } ) <= 1;
            },
        has_preferred => 1,
    }, {
        type  => 'PhoneNumber',
        field => 'phone_number_type_id',
        filter =>    # If it just has a type and allows_sms, we ignore it.
            sub {
            ( true { !string_is_empty($_) } values %{ $_[0] } ) <= 2;
            },
        has_preferred => 1,
    },
);

for my $object (@objects) {
    my $class = 'R2::Schema::' . $object->{type};

    my $id_key = R2::Util::studly_to_calm( $object->{type} );
    my $primary_field = $object->{field} || $id_key;

    my @args = (
        $class,
        $id_key,
        $primary_field,
        $object->{filter},
        $object->{has_preferred},
    );

    __PACKAGE__->meta()->add_method(
        'new_' . $id_key . '_param_sets',
        sub { $_[0]->_new_repeatable_param_sets(@args) },
    );

    __PACKAGE__->meta()->add_method(
        'updated_' . $id_key . '_param_sets',
        sub { $_[0]->_updated_repeatable_param_sets(@args) },
    );
}

sub _new_repeatable_param_sets {
    my $self           = shift;
    my $class          = shift;
    my $key            = shift;
    my $primary_field  = shift;
    my $exclude_filter = shift;
    my $has_preferred  = shift;

    my $params = $self->params();

    my %things;

    my $x = 1;
    while (1) {
        my $suffix = 'new' . $x++;

        last unless exists $params->{ $primary_field . q{-} . $suffix };

        my $thing = $self->_param_set(
            $class,
            $key,
            $suffix,
            $exclude_filter,
            $has_preferred
        ) or next;

        $things{$suffix} = $thing;
    }

    return \%things;
}

sub _updated_repeatable_param_sets {
    my $self           = shift;
    my $class          = shift;
    my $key            = shift;
    shift;
    my $exclude_filter = shift;
    my $has_preferred  = shift;

    my %things;

    my $pk_col = $class->Table()->primary_key()->[0]->name();

    my $params = $self->params();

    for my $id ( $self->param($pk_col) ) {
        my $thing = $self->_param_set(
            $class,
            $key,
            $id,
            $exclude_filter,
            $has_preferred
        ) or next;

        $things{$id} = $thing;
    }

    return \%things;
}

sub _param_set {
    my $self           = shift;
    my $class          = shift;
    my $key            = shift;
    my $suffix         = shift;
    my $exclude_filter = shift;
    my $has_preferred  = shift;

    my %thing = $self->_params_for_classes( [$class], $suffix );

    return if $exclude_filter->( \%thing );

    my $params = $self->params();

    if ( !string_is_empty( $params->{ $key . '_note' . q{-} . $suffix } ) ) {
        $thing{note} = $params->{ $key . '_note' . q{-} . $suffix };
    }

    if ($has_preferred) {
        $thing{is_preferred}
            = $params->{ $key . '_is_preferred' } eq $suffix ? 1 : 0;
    }

    return \%thing;
}

sub custom_field_values {
    my $self = shift;

    my $params = $self->params();

    return
        map { /custom_field_(\d+)/ ? ( $1 => $params->{$_} ) : () }
        keys %{$params};
}

sub members {
    my $self = shift;

    my $params = $self->params();

    my @members;

    for my $key ( grep {/^person_id-/} keys %{$params} ) {
        my ($suffix) = $key =~ /^person_id-(\S+)$/;

        my $position = $params->{ 'position-' . $suffix };

        my %member = ( person_id => $params->{$key} );
        $member{position} = $position;

        push @members, \%member;
    }

    return \@members;
}

sub _bool {
    return $_[0] ? 1 : 0;
}

sub _params_for_classes {
    my $self    = shift;
    my $classes = shift;
    my $suffix  = shift || '';

    my $params = $self->params();

    my %found;

    for my $class ( @{$classes} ) {
        my $table = $class->Table();

        my %pk = map { $_->name() => 1 } @{ $table->primary_key() };

        for my $col ( $table->columns() ) {
            my $name = $col->name();

            next if $pk{$name};

            my $key = $name;
            $key .= q{-} . $suffix
                if $suffix;

            next unless exists $params->{$key};

            if ( string_is_empty( $params->{$key} ) ) {
                $found{$name} = $col->is_nullable() ? undef : q{};
            }
            else {
                $found{$name} = $params->{$key};
            }
        }
    }

    return %found;
}

1;
