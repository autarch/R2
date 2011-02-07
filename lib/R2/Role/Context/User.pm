package R2::Role::Context::User;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema::User;
use R2::Types qw( Maybe );

use Moose::Role;

has 'user' => (
    is      => 'ro',
    isa     => Maybe ['R2::Schema::User'],
    lazy    => 1,
    builder => '_build_user',
);

sub _build_user {
    my $self = shift;

    my $cookie = $self->authen_cookie_value();

    return unless $cookie;

    return R2::Schema::User->new( user_id => $cookie->{user_id} );
}

1;
