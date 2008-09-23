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

sub household_params
{
    my $self = shift;

    return $self->_params_for_classes( [ 'R2::Schema::Household', 'R2::Schema::Contact' ] );
}

sub organization_params
{
    my $self = shift;

    return $self->_params_for_classes( [ 'R2::Schema::Organization', 'R2::Schema::Contact' ] );
}

sub account_params
{
    my $self = shift;

    return $self->_params_for_classes( [ 'R2::Schema::Account' ] );
}

sub donation_sources
{
    my $self = shift;

    my $params = $self->params();

    my %existing =
        ( map  { /^donation_source_name_(\d+)/ ? ( $1 => $params->{$_} ) : () }
          keys %{ $params }
        );

    my @new =
        ( grep { ! string_is_empty($_) }
          map  { $params->{$_} }
          grep { /^donation_source_name_new/ }
          keys %{ $params }
        );

    return ( \%existing, \@new );
}

sub donation_targets
{
    my $self = shift;

    my $params = $self->params();

    my %existing =
        ( map  { /^donation_target_name_(\d+)/ ? ( $1 => $params->{$_} ) : () }
          keys %{ $params }
        );

    my @new =
        ( grep { ! string_is_empty($_) }
          map  { $params->{$_} }
          grep { /^donation_target_name_new/ }
          keys %{ $params }
        );

    return ( \%existing, \@new );
}

sub payment_types
{
    my $self = shift;

    my $params = $self->params();

    my %existing =
        ( map  { /^payment_type_name_(\d+)/ ? ( $1 => $params->{$_} ) : () }
          keys %{ $params }
        );

    my @new =
        ( grep { ! string_is_empty($_) }
          map  { $params->{$_} }
          grep { /^payment_type_name_new/ }
          keys %{ $params }
        );

    return ( \%existing, \@new );
}

sub address_types
{
    my $self = shift;

    my $params = $self->params();

    my %existing =
        ( map  { /^address_type_name_(\d+)/
                 ? ( $1 => $self->_address_type_params($1) )
                 : () }
          keys %{ $params }
        );

    my @new =
        ( grep { ! string_is_empty( $_->{name} ) }
	  map  { /^address_type_name_(new\d+)/
                 ? $self->_address_type_params($1)
                 : () }
          keys %{ $params }
        );

    return ( \%existing, \@new );
}

sub _address_type_params
{
    my $self = shift;
    my $id   = shift;

    my $params = $self->params();

    my $name = $params->{ 'address_type_name_' . $id };
    return {} if string_is_empty($name);

    return { name                    => $name,
	     applies_to_person       => _bool( $params->{ 'applies_to_person_' . $id } ),
	     applies_to_household    => _bool( $params->{ 'applies_to_household_' . $id } ),
	     applies_to_organization => _bool( $params->{ 'applies_to_organization_' . $id } ),
	   };
}

sub phone_number_types
{
    my $self = shift;

    my $params = $self->params();

    my %existing =
        ( map  { /^phone_number_type_name_(\d+)/
                 ? ( $1 => $self->_phone_number_type_params($1) )
                 : () }
          keys %{ $params }
        );

    my @new =
        ( grep { ! string_is_empty( $_->{name} ) }
	  map  { /^phone_number_type_name_(new\d+)/
                 ? $self->_phone_number_type_params($1)
                 : () }
          keys %{ $params }
        );

    return ( \%existing, \@new );
}

sub _phone_number_type_params
{
    my $self = shift;
    my $id   = shift;

    my $params = $self->params();

    my $name = $params->{ 'phone_number_type_name_' . $id };
    return {} if string_is_empty($name);

    return { name                    => $name,
	     applies_to_person       => _bool( $params->{ 'applies_to_person_' . $id } ),
	     applies_to_household    => _bool( $params->{ 'applies_to_household_' . $id } ),
	     applies_to_organization => _bool( $params->{ 'applies_to_organization_' . $id } ),
	   };
}

sub contact_history_types
{
    my $self = shift;

    my $params = $self->params();

    my %existing =
        ( map  { /^(contact_history_type_description_(\d+))/
                 ? ( $2 => $params->{$1}  )
                 : () }
          keys %{ $params }
        );

    my @new =
        ( grep { ! string_is_empty($_) }
	  map  { /^(contact_history_type_description_new\d+)/
                 ? $params->{$1}
                 : () }
          keys %{ $params }
        );

    return ( \%existing, \@new );
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

        push @addresses, \%address;
    }

    return @addresses;
}

sub new_phone_number_param_sets
{
    my $self = shift;

    my $params = $self->params();

    my @numbers;

    my $x = 1;
    while (1)
    {
        my $suffix = 'new' . $x++;

        last unless exists $params->{ 'phone_number_type_id' . q{-} . $suffix };

        my %number =
            $self->_params_for_classes( [ 'R2::Schema::PhoneNumber' ], $suffix );

        # If it just has a type, we ignore it.
        next unless keys %number > 1;

        $number{is_preferred} = $params->{'phone_number_is_preferred'} eq $suffix ? 1 : 0;

        if ( ! string_is_empty( $params->{ 'phone_number_notes' . q{-} . $suffix } ) )
        {
            $number{notes} = $params->{ 'phone_number_notes' . q{-} . $suffix }
        }

        push @numbers, \%number;
    }

    return @numbers;
}

sub _bool
{
    return $_[0] ? 1 : 0;
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

        my %pk = map { $_->name() => 1 } @{ $table->primary_key() };

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

1;
