package R2::Plugin::User;

use strict;
use warnings;

use R2::Schema::User;


sub user
{
    my $self = shift;

    return $self->{'R2::Plugin::User::user'} ||= $self->_user_for_request();
}

sub _user_for_request
{
    my $self = shift;

    my $cookie = $self->authen_cookie_value();

    my $user;
    $user = R2::Schema::User->new( user_id => $cookie->{user_id} )
        if $cookie;

    return $user;
}

1;
