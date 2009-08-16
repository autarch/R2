package R2::Request;

use strict;
use warnings;

use Moose::Role;

use List::AllUtils qw( true );
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

sub donation_params
{
    my $self = shift;

    return $self->_params_for_classes( [ 'R2::Schema::Donation' ] );
}

sub note_params
{
    my $self = shift;

    return $self->_params_for_classes( [ 'R2::Schema::ContactNote' ] );
}

sub donation_sources
{
    my $self = shift;

    my $params = $self->params();

    my %existing =
        ( map  { /^donation_source_name_(\d+)/ ? ( $1 => { name => $params->{$_} } ) : () }
          keys %{ $params }
        );

    my @new =
        ( map  { +{ name => $_ } }
          grep { ! string_is_empty($_) }
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
        ( map  { /^donation_target_name_(\d+)/ ? ( $1 => { name => $params->{$_} } ) : () }
          keys %{ $params }
        );

    my @new =
        ( map  { +{ name => $_ } }
          grep { ! string_is_empty($_) }
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
        ( map  { /^payment_type_name_(\d+)/ ? ( $1 => { name => $params->{$_} } ) : () }
          keys %{ $params }
        );

    my @new =
        ( map  { +{ name => $_ } }
          grep { ! string_is_empty($_) }
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

sub contact_note_types
{
    my $self = shift;

    my $params = $self->params();

    my %existing =
        ( map  { /^(contact_note_type_description_(\d+))/
                 ? ( $2 => { description => $params->{$1} }  )
                 : () }
          keys %{ $params }
        );

    my @new =
        ( map  { +{ description => $_ } }
          grep { ! string_is_empty($_) }
	  map  { /^(contact_note_type_description_new\d+)/
                 ? $params->{$1}
                 : () }
          keys %{ $params }
        );

    return ( \%existing, \@new );
}

sub updated_email_address_param_sets
{
    my $self = shift;

    return
        $self->_updated_repeatable_param_sets
            ( 'R2::Schema::EmailAddress',
              'email_address_id',
              'email_address',
              sub { string_is_empty( $_[0]->{email_address} ) },
              'has preferred',
            );
}

sub _updated_repeatable_param_sets
{
    my $self           = shift;
    my $class          = shift;
    my $id_field       = shift;
    my $key            = shift;
    my $exclude_filter = shift;
    my $has_preferred  = shift;

    my %things;

    my $params = $self->params();

    for my $suffix ( $self->param($id_field) )
    {
        my %thing =
            $self->_params_for_classes( [ $class ], $suffix );

        next if $exclude_filter->( \%thing );

        if ( ! string_is_empty( $params->{ $key . '_note' . q{-} . $suffix } ) )
        {
            $thing{note} = $params->{ $key . '_note' . q{-} . $suffix }
        }

        if ($has_preferred)
        {
            $thing{is_preferred} = $params->{ $key . '_is_preferred' } eq $suffix ? 1 : 0;
        }

        $things{$suffix} = \%thing;
    }

    return \%things;
}

sub new_email_address_param_sets
{
    my $self = shift;

    return
        $self->_new_repeatable_param_sets
            ( 'R2::Schema::EmailAddress',
              'email_address',
              'email_address',
              sub { string_is_empty( $_[0]->{email_address} ) },
              'has preferred',
            );
}

sub new_website_param_sets
{
    my $self = shift;

    return
        $self->_new_repeatable_param_sets
            ( 'R2::Schema::Website',
              'website',
              'uri',
              sub { string_is_empty( $_[0]->{uri} ) },
            );
}

sub new_address_param_sets
{
    my $self = shift;

    return
        $self->_new_repeatable_param_sets
            ( 'R2::Schema::Address',
              'address',
              'address_type_id',
              # If it just has a type and country, we ignore it.
              sub { ( true { ! string_is_empty($_) } values %{ $_[0] } ) <= 2 },
              'has preferred',
            );
}

sub new_phone_number_param_sets
{
    my $self = shift;

    return
        $self->_new_repeatable_param_sets
            ( 'R2::Schema::PhoneNumber',
              'phone_number',
              'phone_number_type_id',
              # If it just has a type, we ignore it.
              sub { ( true { ! string_is_empty($_) } values %{ $_[0] } ) <= 1 },
              'has preferred',
            );
}

sub _new_repeatable_param_sets
{
    my $self           = shift;
    my $class          = shift;
    my $key            = shift;
    my $primary_field  = shift;
    my $exclude_filter = shift;
    my $has_preferred  = shift;

    my $params = $self->params();

    my %things;

    my $x = 1;
    while (1)
    {
        my $suffix = 'new' . $x++;

        last unless exists $params->{ $primary_field . q{-} . $suffix };

        my %thing =
            $self->_params_for_classes( [ $class ], $suffix );

        next if $exclude_filter->( \%thing );

        if ( ! string_is_empty( $params->{ $key . '_note' . q{-} . $suffix } ) )
        {
            $thing{note} = $params->{ $key . '_note' . q{-} . $suffix }
        }

        if ($has_preferred)
        {
            $thing{is_preferred} = $params->{ $key . '_is_preferred' } eq $suffix ? 1 : 0;
        }

        $things{$suffix} = \%thing;
    }

    return \%things;
}

sub custom_field_values
{
    my $self = shift;

    my $params = $self->params();

    return map { /custom_field_(\d+)/ ? ( $1 => $params->{$_} ) : () } keys %{ $params };
}

sub members
{
    my $self = shift;

    my $params = $self->params();

    my @members;

    for my $key ( grep { /^person_id-/ } keys %{ $params } )
    {
        my ($suffix) = $key =~ /^person_id-(\S+)$/;

        my $position = $params->{ 'position-' . $suffix };

        my %member = ( person_id => $params->{$key} );
        $member{position} = $position
            unless string_is_empty($position);

        push @members, \%member;
    }

    return \@members;
}

sub custom_field_groups
{
    my $self = shift;

    my $params = $self->params();

    my %existing =
        ( map  { /^custom_field_group_name_(\d+)/
                 ? ( $1 => $self->_custom_field_group_params($1) )
                 : () }
          keys %{ $params }
        );

    my @new =
        ( grep { ! string_is_empty( $_->{name} ) }
	  map  { /^custom_field_group_name_(new\d+)/
                 ? $self->_custom_field_group_params($1)
                 : () }
          keys %{ $params }
        );

    return ( \%existing, \@new );
}

sub _custom_field_group_params
{
    my $self = shift;
    my $id   = shift;

    my $params = $self->params();

    my $name = $params->{ 'custom_field_group_name_' . $id };
    return {} if string_is_empty($name);

    return { name                    => $name,
	     applies_to_person       => _bool( $params->{ 'applies_to_person_' . $id } ),
	     applies_to_household    => _bool( $params->{ 'applies_to_household_' . $id } ),
	     applies_to_organization => _bool( $params->{ 'applies_to_organization_' . $id } ),
	   };
}

sub custom_fields
{
    my $self = shift;

    my $params = $self->params();

    my %existing =
        ( map  { /^custom_field_label_(\d+)/
                 ? ( $1 => $self->_custom_field_params($1) )
                 : () }
          keys %{ $params }
        );

    my @new =
        ( grep { ! string_is_empty( $_->{label} ) }
	  map  { /^custom_field_label_(new\d+)/
                 ? $self->_custom_field_params($1)
                 : () }
          keys %{ $params }
        );

    return ( \%existing, \@new );
}

sub _custom_field_params
{
    my $self = shift;
    my $id   = shift;

    my $params = $self->params();

    my $label = $params->{ 'custom_field_label_' . $id };
    return {} if string_is_empty($label);

    return { label       => $label,
             description => $params->{ 'custom_field_description_' . $id },
             type        => $params->{ 'custom_field_type_' . $id },
             is_required => $params->{ 'custom_field_is_required_' . $id },
           };
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

            if ( string_is_empty( $params->{$key} ) )
            {
                if ( $col->is_nullable() )
                {
                    $found{$name} = undef;
                }

                next;
            }

            $found{$name} = $params->{$key};
        }
    }

    return %found;
}

no Moose::Role;

1;
