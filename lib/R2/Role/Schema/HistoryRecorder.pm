package R2::Role::Schema::HistoryRecorder;

use strict;
use warnings;
use namespace::autoclean;

use Carp qw( confess );
use Lingua::EN::Inflect qw( A );
use R2::Schema::ContactHistory;
use R2::Schema::ContactHistoryType;
use Storable qw( nfreeze );

use MooseX::Role::Parameterized;

#requires_attr 'contact_id';

requires qw( Table insert update delete );

my $_history_types_for_class = sub {
    my $class = shift;

    if ( $class->does_role('R2::Role::Schema::ActsAsContact') ) {
        return (
            insert => R2::Schema::ContactHistoryType->Created(),
            update => R2::Schema::ContactHistoryType->Modified(),
        );
    }
    else {
        ( my $thing = $class->name() ) =~ s/^R2::Schema:://;
        my $add    = 'Add' . $thing;
        my $modify = 'Modify' . $thing;
        my $delete = 'Delete' . $thing;

        my %types = (
            insert => R2::Schema::ContactHistoryType->$add(),
            delete => R2::Schema::ContactHistoryType->$delete(),
        );

        # Some history recorder classes only record inserts and deletes (like
        # HouseholdMember).
        $types{update} = R2::Schema::ContactHistoryType->$modify()
            if R2::Schema::ContactHistoryType->can($modify);

        return %types;
    }
};

my $_make_insert_wrapper = sub {
    my $class         = shift;
    my $history_attrs = shift;
    my $type          = shift;

    my @pk = map { $_->name() } @{ $class->Table()->primary_key() };

    return sub {
        my $orig  = shift;
        my $class = shift;
        my %p     = @_;

        my $user = delete $p{user}
            or confess "Inserting a $class requires a user parameter";

        my $row;

        R2::Schema->RunInTransaction(
            sub {
                $row = $class->$orig(%p);

                my %history_p;
                while ( my ( $key, $meth ) = each %{$history_attrs} ) {
                    $history_p{$key} = $row->$meth();
                }

                my $reversal = {
                    class              => $class,
                    constructor_params => { map { $_ => $row->$_() } @pk },
                    method             => 'delete',
                };

                my $description = $type->description();
                $description .= ' - ' . $row->summary()
                    if $row->can('summary');

                R2::Schema::ContactHistory->insert(
                    %history_p,
                    user_id => $user->user_id(),
                    contact_history_type_id =>
                        $type->contact_history_type_id(),
                    description   => $description,
                    reversal_blob => nfreeze($reversal),
                );
            }
        );

        return $row;
    };
};

my $_make_update_wrapper = sub {
    my $class         = shift;
    my $history_attrs = shift;
    my $type          = shift;

    my @pk = map { $_->name() } @{ $class->Table()->primary_key() };

    return sub {
        my $orig = shift;
        my $self = shift;
        my %p    = @_;

        my $user = delete $p{user}
            or confess "Updating a "
            . ( ref $self )
            . " requires a user parameter";

        my %original = map { $_ => $self->$_() } keys %p;

        R2::Schema->RunInTransaction(
            sub {
                my %history_p;
                while ( my ( $key, $meth ) = each %{$history_attrs} ) {
                    $history_p{$key} = $self->$meth();
                }

                my $reversal = {
                    class              => $class,
                    constructor_params => { map { $_ => $self->$_() } @pk },
                    method             => 'update',
                    method_params      => \%original,
                };

                my $description = $type->description();
                $description .= ' - ' . $self->summary()
                    if $self->can('summary');

                $self->$orig(%p);

                R2::Schema::ContactHistory->insert(
                    %history_p,
                    user_id => $user->user_id(),
                    contact_history_type_id =>
                        $type->contact_history_type_id(),
                    description   => $description,
                    reversal_blob => nfreeze($reversal),
                );
            }
        );
    };
};

my $_make_delete_wrapper = sub {
    my $class         = shift;
    my $history_attrs = shift;
    my $type          = shift;

    my @pk = map { $_->name() } @{ $class->Table()->primary_key() };

    my %in_pk = map { $_ => 1 } @pk;

    my @not_pk = grep { !$in_pk{$_} }
        map { $_->name() } $class->Table()->columns();

    return sub {
        my $orig = shift;
        my $self = shift;
        my %p    = @_;

        my $user = delete $p{user}
            or confess "Deleting a "
            . ( ref $self )
            . " requires a user parameter";

        R2::Schema->RunInTransaction(
            sub {
                my %history_p;
                while ( my ( $key, $meth ) = each %{$history_attrs} ) {
                    $history_p{$key} = $self->$meth();
                }

                my %original = map { $_ => $self->$_() } @not_pk;

                my $reversal = {
                    class         => $class,
                    method        => 'insert',
                    method_params => \%original,
                };

                my $description = $type->description();
                $description .= ' - ' . $self->summary()
                    if $self->can('summary');

                $self->$orig(%p);

                R2::Schema::ContactHistory->insert(
                    %history_p,
                    user_id => $user->user_id(),
                    contact_history_type_id =>
                        $type->contact_history_type_id(),
                    description   => $description,
                    reversal_blob => nfreeze($reversal),
                );
            }
        );
    };
};

role {
    shift;
    my %extra = @_;

    my $consumer = $extra{consumer};

    my %history_attrs = map { $_ => $_ }
        grep { $consumer->has_method($_) }
        qw( contact_id email_address_id website_id address_id phone_number_id );

    $history_attrs{contact_id} = 'contact_id_for_history'
        if $consumer->has_method('contact_id_for_history');

    $history_attrs{other_contact_id} = 'other_contact_id_for_history'
        if $consumer->has_method('other_contact_id_for_history');

    my %types = $_history_types_for_class->($consumer);

    if ( $types{insert} ) {
        around 'insert' => $_make_insert_wrapper->(
            $consumer->name(),
            \%history_attrs,
            $types{insert},
        );
    }

    if ( $types{update} ) {
        around 'update' => $_make_update_wrapper->(
            $consumer->name(),
            \%history_attrs,
            $types{update},
        );
    }

    if ( $types{delete} ) {
        around 'delete' => $_make_delete_wrapper->(
            $consumer->name(),
            \%history_attrs,
            $types{delete},
        );
    }
};

1;
