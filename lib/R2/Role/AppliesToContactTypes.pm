package R2::Role::AppliesToContactTypes;

use strict;
use warnings;

use Lingua::EN::Inflect qw( A );
use List::AllUtils qw( any );
use R2::Util qw( studly_to_calm );

use Moose::Role;

# these are attributes
#requires qw( person_count household_count organization_count contact_count );


my @ContactTypes = qw( person household organization );

# These two subs are data validation steps
sub _cannot_unapply
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if $is_insert;

    for my $contact_type (@ContactTypes)
    {
        my $key = 'applies_to_' . $contact_type;

        if ( exists $p->{$key} && ! $p->{$key} )
        {
            my $meth = 'can_unapply_from_' . $contact_type;

            delete $p->{$key}
                unless $self->$meth();
        }
    }

    return;
}

sub _applies_to_something
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    my @keys = map { 'applies_to_' . $_ } @ContactTypes;

    if ($is_insert)
    {
        return if
            any { exists $p->{$_} && $p->{$_} } @keys;
    }
    else
    {
        for my $key (@keys)
        {
            if ( exists $p->{$key} )
            {
                return if $p->{$key};
            }
            else
            {
                return if $self->$key();
            }
        }
    }

    ( my $thing = (ref $self || $self) ) =~ s/R2::Schema:://;

    $thing = studly_to_calm($thing);
    $thing =~ s/_/ /g;

    my $articled_thing = ucfirst A($thing);

    return { message =>
             "$articled_thing must apply to a person, household, or organization." };
}

sub types_applied_to
{
    my $self = shift;

    return
        ( map { ucfirst $_ }
          grep { my $meth = 'applies_to_' . $_; $self->$meth() }
          @ContactTypes
        );
}

sub can_unapply_from_person
{
    my $self = shift;

    return ! $self->person_count();
}

sub can_unapply_from_household
{
    my $self = shift;

    return ! $self->household_count();
}

sub can_unapply_from_organization
{
    my $self = shift;

    return ! $self->organization_count();
}

sub is_deletable
{
    my $self = shift;

    return ! $self->contact_count();
}

no Moose::Role;

1;
