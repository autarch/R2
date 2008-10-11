package R2::Plugin::Account;

use strict;
use warnings;

use R2::Schema::Account;


sub account
{
    my $self = shift;

    return exists $self->{'R2::Plugin::User::account'}
           ? $self->{'R2::Plugin::User::account'}
           : $self->{'R2::Plugin::User::account'} ||= $self->_account_for_request();
}

sub _account_for_request
{
    my $self = shift;

    my $user = $self->user()
        or return;

    return $user->account();
}

1;
