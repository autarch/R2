package R2::Role::Context::RedirectWithError;

use strict;
use warnings;
use namespace::autoclean;

use HTTP::Status qw( RC_OK );
use JSON::XS;

use Moose::Role;
use MooseX::Params::Validate qw( validated_hash validated_list );
use R2::Types qw( ErrorForSession URIStr );

# These are not available yet?
#requires qw( redirect_and_detach session_object );

{
    my @spec = (
        uri   => { isa => URIStr,          coerce   => 1 },
        error => { isa => ErrorForSession, optional => 1 },
    );

    sub redirect_with_error {
        my $self = shift;
        my %p = validated_hash( \@_, @spec );

        die "Must provide a form or error" unless $p{error} || $p{form};

        $self->session_object()->add_error( $p{error} )
            if $p{error};

        $self->_redirect( $p{uri} );
    }
}

{
    my @spec = (
        uri       => { isa => URIStr, coerce => 1 },
        resultset => { isa => 'Chloro::ResultSet' },
    );

    sub redirect_with_resultset {
        my $self = shift;
        my ( $uri, $resultset ) = validated_list( \@_, @spec );

        $self->session_object()->set_resultset($resultset);

        $self->_redirect($uri);
    }
}

my $JSON = JSON::XS->new();
$JSON->pretty(1);
$JSON->utf8(1);

sub _redirect {
    my $self = shift;
    my $uri  = shift;

    if ( $self->request()->looks_like_browser() ) {
        $self->redirect_and_detach($uri);
    }
    else {
        $uri = $self->uri_with_sessionid($uri);

        $self->response()->status(RC_OK);
        $self->response()->body( $JSON->encode( { uri => $uri } ) );
        $self->detach();
    }
}

1;
