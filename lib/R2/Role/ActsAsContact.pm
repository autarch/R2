package R2::Role::ActsAsContact;

use strict;
use warnings;

use R2::Schema::Contact;

use Moose::Role;

with 'R2::Role::DataValidator' => { excludes => '_validation_errors' };

# Can't use Fey::ORM::Table in a role yet
#
# has_one 'contact' => ...


# This is a bit inelegant, since it means that the contact validations
# will run twice on insert and update. In practice, this isn't _that_
# big a deal, since if it fails it will fail before running the second
# time, and if it passes once, it will pass twice.
sub _validation_errors
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    my ( $contact_p, $my_p ) = $self->_filter_contact_parameters( %{ $p } );

    my @errors;
    for my $step ( @{ $self->_ValidationSteps() } )
    {
        push @errors, $self->$step( $my_p, $is_insert );
    }

    for my $step ( @{ R2::Schema::Contact->_ValidationSteps() } )
    {
        push @errors, R2::Schema::Contact->$step( $contact_p, $is_insert );
    }

    return @errors;
}

sub _filter_contact_parameters
{
    my $self = shift;
    my %p    = @_;

    my %contact_p =
        map { $_ => delete $p{$_} } grep { R2::Schema::Contact->Table()->column($_) } keys %p;

    return ( \%contact_p, \%p );
}

around 'insert' => sub
{
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    my ( $contact_p, $my_p ) = $class->_filter_contact_parameters(%p);

    ( my $contact_type = $class ) =~ s/^R2::Schema:://;
    my $pk_name = lc $contact_type . '_id';

    my $sub = sub { my $contact =
                        R2::Schema::Contact->insert( %{ $contact_p },
                                                     contact_type => $contact_type,
                                                   );

                    my $self =
                        $class->$orig( %{ $my_p },
                                       $pk_name => $contact->contact_id(),
                                     );

                    $self->_set_contact($contact);

                    return $self;
                  };

    return R2::Schema->RunInTransaction($sub);
};

around 'update' => sub
{
    my $orig = shift;
    my $self = shift;
    my %p    = @_;

    my ( $contact_p, $my_p ) = $self->_filter_contact_parameters(%p);

    my $sub = sub { my $contact = $self->contact();

                    $contact->update( %{ $contact_p } );

                    $self->$orig( %{ $my_p } );
                  };

    return R2::Schema->RunInTransaction($sub);
};

no Moose::Role;

1;
