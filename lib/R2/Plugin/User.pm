package R2::Plugin::User;

use strict;
use warnings;

use R2::Schema::User;

use Moose::Role;

has 'user' =>
    ( is         => 'ro',
      isa        => 'R2::Schema::User|Undef',
      lazy_build => 1,
    );


sub _build_user
{
    my $self = shift;

    my $cookie = $self->authen_cookie_value();

    return unless $cookie;

    return R2::Schema::User->new( user_id => $cookie->{user_id} );
}

no Moose::Role;

1;
