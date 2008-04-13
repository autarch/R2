package R2::Role::DataValidator;

use strict;
use warnings;

use R2::Exceptions qw( data_validation_error );

use Moose::Role;


#requires_attr '_ValidationSteps';

# This doesn't work so well when we're trying to create a bunch of
# objects in one transaction, either from a controller or model. A
# good model example is Person, which tries to create a Contact
# internally.
#
# What we want is to capture all the validation errors for all the
# objects, but as it is the first class to fail validation will abort
# all further processing.
#
# This is tricky to solve, especially since a failure to create object
# A may make it impossible to create object B, but we'd still like to
# validate B's data as much as possible.
#
# Maybe the solution is to expose the validation via public methods
# and have the controller do all the validations up front?

around 'insert' => sub
{
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    $class->_clean_and_validate_data( \%p, 'is insert' )
        if $class->can('_ValidationSteps');

    return $class->$orig(%p);
};

around 'update' => sub
{
    my $orig = shift;
    my $self = shift;
    my %p    = @_;

    $self->_clean_and_validate_data(\%p)
        if $self->can('_ValidationSteps');

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

    return @errors;
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
