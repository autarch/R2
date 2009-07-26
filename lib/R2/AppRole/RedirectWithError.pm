package R2::AppRole::RedirectWithError;

use strict;
use warnings;

use HTTP::Status qw( RC_OK );
use JSON::XS;

use Moose::Role;
use MooseX::Params::Validate qw( validated_hash );

# These are not available yet?
#requires qw( redirect_and_detach session_object );


my $JSON = JSON::XS->new();
$JSON->pretty(1);
$JSON->utf8(1);

my %spec = ( uri   => { isa => 'R2.Type.URIStr', coerce => 1 },
             error => { isa => 'R2.Type.ErrorForSession', default => undef },
             form  => { isa => 'Chloro::Object', default => undef },
           );

sub redirect_with_error
{
    my $self = shift;
    my %p    = validated_hash( \@_, %spec );

    die "Must provide a form or error" unless $p{error} || $p{form};

    $self->session_object()->add_error( $p{error} )
        if $p{error};
    $self->session_object()->set_form( $p{form} )
        if $p{form};

    if ( $self->request()->looks_like_browser() )
    {
        $self->redirect_and_detach( $p{uri} );
    }
    else
    {
        my $uri = $self->uri_with_sessionid( $p{uri} );

        $self->response()->status(RC_OK);
        $self->response()->body( $JSON->encode( { uri => $uri } ) );
        $self->detach();
    }
}

no Moose::Role;

1;
