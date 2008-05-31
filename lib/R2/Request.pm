package R2::Request;

use strict;
use warnings;

use base 'Catalyst::Request::REST::ForBrowsers';

use R2::Util qw( string_is_empty );


sub person_params
{
    my $self = shift;

    return $self->_params_for_classes( [ 'R2::Schema::Person', 'R2::Schema::Contact' ] );
}

sub _params_for_classes
{
    my $self    = shift;
    my $classes = shift;
    my $suffix  = shift || '';

    my $params = $self->params();

    my %found;

    for my $class ( @{ $classes } )
    {
        my $table = $class->Table();

        my %pk = map { $_->name() => 1 } $table->primary_key();

        for my $col ( $table->columns() )
        {
            my $name = $col->name();

            next if $pk{$name};

            my $key = $name;
            $key .= q{-} . $suffix
                if $suffix;

            next if string_is_empty( $params->{$key} );

            $found{$name} = $params->{$key};
        }
    }

    return %found;
}

sub new_address_param_sets
{
    my $self = shift;

    my $params = $self->params();

    my @addresses;

    my $x = 1;
    while (1)
    {
        my $suffix = 'new' . $x++;

        last unless exists $params->{ 'address_type_id' . q{-} . $suffix };

        my %address =
            $self->_params_for_classes( [ 'R2::Schema::Address' ], $suffix );

        # If it just has a type and country, we ignore it.
        next unless keys %address > 2;

        $address{is_preferred} = $params->{'address_is_preferred'} eq $suffix ? 1 : 0;

        if ( ! string_is_empty( $params->{ 'address_notes' . q{-} . $suffix } ) )
        {
            $address{notes} = $params->{ 'address_notes' . q{-} . $suffix }
        }

        # The user can create an address field set but not fill in any
        # of the parameters besides type and country.
        next unless keys %address > 2;

        push @addresses, \%address;
    }

    return @addresses;
}


1;
