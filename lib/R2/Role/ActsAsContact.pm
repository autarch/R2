package R2::Role::ActsAsContact;

use strict;
use warnings;

use R2::Schema::Contact;

use Moose::Role;

with 'R2::Role::HistoryRecorder';

# Can't use Fey::ORM::Table in a role yet
#
# has_one 'contact' => ...

requires '_build_friendly_name', 'display_name';

has 'friendly_name' =>
    ( is         => 'ro',
      isa        => 'Str',
      lazy_build => 1,
    );

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

    if ( $self->can('_ValidationSteps') )
    {
        for my $step ( @{ $self->_ValidationSteps() } )
        {
            push @errors, $self->$step( $my_p, $is_insert );
        }
    }

    if ( R2::Schema::Contact->can('_ValidationSteps') )
    {
        for my $step ( @{ R2::Schema::Contact->_ValidationSteps() } )
        {
            push @errors, R2::Schema::Contact->$step( $contact_p, $is_insert );
        }
    }

    {
        # This is nasty hack to make sure we don't throw an error
        # because the primary key is null (person_id, household_id,
        # etc) on insert. This will not be null when we do the real
        # insert, because it will be the same as the newly created
        # contact_id.
        my $temp_p = {};
        %{ $temp_p } = %{ $my_p };

        $temp_p->{ $self->Table()->primary_key()->[0]->name() } = 0;

        push @errors, $self->_check_non_nullable_columns( $temp_p, $is_insert );
    }

    # The validation steps may have altered the data. It will get
    # filtered again for the actual insert.
    %{ $p } = ( %{ $contact_p }, %{ $my_p } );

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
