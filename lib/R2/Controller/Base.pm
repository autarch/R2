package R2::Controller::Base;

use strict;
use warnings;

use base 'Catalyst::Controller';

# Normally I'd inherit from this class, but that seems to magically
# break handling of "normal" views (the various *_GET_html
# methods). Instead we'll manually "import" the handy status related
# methods it provides, which is pretty lame.
use Catalyst::Controller::REST;

BEGIN
{
    for my $meth ( qw( status_ok status_created status_accepted
                       status_bad_request status_not_found ) )
    {
        no strict 'refs';
        *{ __PACKAGE__ . '::' . $meth } = \&{ 'Catalyst::Controller::REST::' . $meth };
    }
}

use R2::Config;
use R2::Web::CSS;
use R2::Web::Javascript;


sub begin : Private
{
    my $self = shift;
    my $c    = shift;

    R2::Schema->ClearObjectCaches();

    return unless $c->request()->looks_like_browser();

    my $config = R2::Config->new();

    for my $class ( qw( R2::Web::CSS R2::Web::Javascript ) )
    {
        $class->new()->create_single_file()
            unless $config->is_production() || $config->is_profiling();
    }

    return 1;
}

sub end : Private
{
    my $self = shift;
    my $c    = shift;

    return $self->NEXT::end($c)
        if $c->stash()->{rest};

    if ( ( ! $c->response()->status()
           || $c->response()->status() == 200 )
         && ! $c->response()->body()
         && ! @{ $c->error() || [] } )
    {
        $c->forward( $c->view() );
    }

    return;
}

sub _require_authen
{
    my $self = shift;
    my $c    = shift;

    my $user = $c->user();

    return if $user;

    $c->redirect_and_detach( '/user/login_form' );
}

# XXX - belongs in request?
sub _params_from_path_query
{
    my $self = shift;
    my $path = shift;

    return if string_is_empty($path);

    my %p;
    for my $kv ( split /;/, $path )
    {
        my ( $k, $v ) = map { uri_unescape($_) } split /=/, $kv;

        if ( $p{$k} )
        {
            if ( ref $p{$k} )
            {
                push @{ $p{$k} }, $v;
            }
            else
            {
                $p{$k} = [ $p{$k}, $v ];
            }
        }
        else
        {
            $p{$k} = $v;
        }
    }

    return %p;
}

1;
