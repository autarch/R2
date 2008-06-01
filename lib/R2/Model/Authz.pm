package R2::Model::Authz;

use strict;
use warnings;

use MooseX::Params::Validate qw( validatep );
use R2::Schema;
use R2::Schema::Account;
use R2::Schema::Contact;
use R2::Schema::Role;
use R2::Schema::User;


sub user_can_view_account
{
    my $self = shift;
    my ( $user, $account ) =
        validatep( \@_,
                   user    => { isa => 'R2::Schema::User' },
                   account => { isa => 'R2::Schema::Account' },
                 );

    return $self->_require_at_least( $user->user_id(), $account->account_id(), 'Admin' );
}

sub user_can_edit_account
{
    my $self = shift;
    my ( $user, $account ) =
        validatep( \@_,
                   user    => { isa => 'R2::Schema::User' },
                   account => { isa => 'R2::Schema::Account' },
                 );

    return $self->_require_at_least( $user->user_id(), $account->account_id(), 'Admin' );
}

sub user_can_view_contact
{
    my $self = shift;
    my ( $user, $contact ) =
        validatep( \@_,
                   user    => { isa => 'R2::Schema::User' },
                   contact => { isa => 'R2::Schema::Contact' },
                 );

    return $self->_require_at_least( $user->user_id(), $contact->account_id(), 'Member' );
}

sub user_can_edit_contact
{
    my $self = shift;
    my ( $user, $contact ) =
        validatep( \@_,
                   user    => { isa => 'R2::Schema::User' },
                   contact => { isa => 'R2::Schema::Contact' },
                 );

    return 0 unless $user->account_id() == $contact->account_id();

    return $self->_require_at_least( $user->user_id(), $contact->account_id(), 'Editor' );
}

sub user_can_add_contact
{
    my $self = shift;
    my ( $user, $account ) =
        validatep( \@_,
                   user    => { isa => 'R2::Schema::User' },
                   account => { isa => 'R2::Schema::Account' },
                 );

    return $self->_require_at_least( $user->user_id(), $account->account_id(), 'Editor' );
}

{
    # This could go in the DBMS, but I'm uncomfortable with making
    # this a formal part of the data model. There could be additional
    # roles in the future that don't fit into this sort of scheme, so
    # keeping this ranking in code preserves the flexibility to
    # eliminate it entirely.
    my %RoleRank = ( Member => 1,
                     Editor => 2,
                     Admin  => 3,
                   );

    sub _require_at_least
    {
        my $self       = shift;
        my $user_id    = shift;
        my $account_id = shift;
        my $required   = shift;

        my $acr =
            R2::Schema::AccountUserRole->new( account_id => $account_id,
                                              user_id    => $user_id,
                                            );

        return 0 unless $acr;

        my $role = $acr->role();

        return $RoleRank{ $role->name() } >= $RoleRank{$required} ? 1 : 0;
    }
}

1;
