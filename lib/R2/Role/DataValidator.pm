package R2::Role::DataValidator;

use strict;
use warnings;

use R2::Exceptions qw( data_validation_error );

use Moose::Role;


around 'insert' => sub
{
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    $class->_clean_and_validate_data( \%p, 'is insert' );

    return $class->$orig(%p);
};

around 'update' => sub
{
    my $orig = shift;
    my $self = shift;
    my %p    = @_;

    $self->_clean_and_validate_data(\%p);

    return $self->$orig(%p);
};

sub _clean_and_validate_data
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    my @errors = $self->_validation_errors( $p, $is_insert );

    data_validation_error errors => \@errors
        if @errors;
}

sub _validation_errors
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    my @errors;
    for my $step ( @{ $self->_ValidationSteps() } )
    {
        push @errors, $self->$step( $p, $is_insert );
    }

    push @errors, $self->_check_non_nullable_columns( $p, $is_insert );

    return @errors;
}

sub _check_non_nullable_columns
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    my @errors;
    for my $name ( map { $_->name() }
                   grep { ! ( $_->is_nullable() || defined $_->default() || $_->is_auto_increment() ) }
                   $self->Table()->columns() )
    {
        if ($is_insert)
        {
            push @errors, $self->_needs_value_error($name)
                unless exists $p->{$name} && defined $p->{$name};
        }
        else
        {
            push @errors, $self->_needs_value_error($name)
                if exists $p->{$name} && ! defined $p->{$name};
        }
    }

    return @errors;
}

sub _needs_value_error
{
    my $self = shift;
    my $name = shift;

    ( my $friendly_name = ucfirst $name ) =~ s/_/ /g;

    return { field   => $name,
             message => "You must provide a $friendly_name." };
}

sub ValidateForInsert
{
    my $class = shift;
    my %p     = @_;

    return $class->_validation_errors( \%p, 'is insert' );
}

sub validate_for_update
{
    my $self = shift;
    my %p    = @_;

    return $self->_validation_errors(\%p);
}

no Moose::Role;

1;
