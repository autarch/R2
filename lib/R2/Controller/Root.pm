package R2::Controller::Root;

use strict;
use warnings;

use base 'R2::Controller::Base';

use R2::Config;
use R2::Exceptions;

__PACKAGE__->config()->{namespace} = '';



sub dashboard : Path('/') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/dashboard';
}

sub exit : Path('/exit') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    R2::Exception->throw( 'Naughty attempt to kill R2' )
        if R2::Config->new()->is_production();

    exit 0;
}

sub die : Path('/die') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    R2::Exception->throw( 'Naughty attempt to kill R2' )
        if R2::Config->new()->is_production();

    die 'Dead';
}

sub robots_txt : Path('/robots.txt') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    $c->response()->content_type('text/plain');
    $c->response()->body("User-agent: *\nDisallow: /\n");
}

1;

__END__
