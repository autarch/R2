package R2::Plugin::Account;

use strict;
use warnings;

use R2::Schema::Account;

use Moose::Role;

has 'account' =>
    ( is         => 'ro',
      isa        => 'R2::Schema::Account|Undef',
      lazy_build => 1,
    );


sub _build_account
{
    my $self = shift;

    my $user = $self->user()
        or return;

    return $user->account();
}

1;
