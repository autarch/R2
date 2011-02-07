package R2::Role::Context::Account;

use strict;
use warnings;

use R2::Schema::Account;
use R2::Types qw( Maybe );

use Moose::Role;

has 'account' => (
    is      => 'ro',
    isa     => Maybe['R2::Schema::Account'],
    lazy    => 1,
    builder => '_build_account',
);

sub _build_account {
    my $self = shift;

    my $user = $self->user()
        or return;

    return $user->account();
}

1;
