package R2::Role::DataValidator;

use strict;
use warnings;

use R2::Exceptions qw( data_validation_error );

use Moose::Role;


#requires_attr '_ValidationSteps';

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

    my @errors;
    for my $step ( @{ $self->_ValidationSteps() } )
    {
        push @errors, $self->$step( $p, $is_insert );
    }

    data_validation_error errors => \@errors
        if @errors;
}

no Moose::Role;

1;
