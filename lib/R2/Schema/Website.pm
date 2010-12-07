package R2::Schema::Website;

use strict;
use warnings;
use namespace::autoclean;

use Data::Validate::URI qw( is_web_uri );
use R2::Schema;
use R2::Schema::Contact;
use R2::Util qw( string_is_empty );
use URI;
use URI::http;

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator' =>
    { steps => [qw( _validate_and_canonicalize_uri )] };
with 'R2::Role::Schema::HistoryRecorder';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Website') );

    has_one( $schema->table('Contact') );

    transform 'uri' =>
        deflate { blessed $_[1] ? $_[1]->canonical() . '' : $_[1] },
        inflate { defined $_[1] ? URI->new( $_[1] ) : $_[1] };
}

sub _validate_and_canonicalize_uri {
    my $self = shift;
    my $p    = shift;

    return if string_is_empty( $p->{uri} );

    my $canonical = $self->_canonicalize_uri( $p->{uri} );

    return {
        message => qq{"$p->{uri}" is not a valid web address.},
        field   => 'uri',
        }
        unless is_web_uri($canonical);

    $p->{uri} = $canonical;

    return;
}

sub _canonicalize_uri {
    my $self = shift;
    my $uri  = shift;

    $uri = URI->new(
          $uri =~ /^https?/
        ? $uri
        : 'http://' . $uri
    );

    if ( ( $uri->scheme() && $uri->scheme() !~ /^https?/ )
        || string_is_empty( $uri->host() ) ) {
        return undef;
    }

    return $uri->canonical() . '';
}

sub summary { $_[0]->label() . q{: } . $_[0]->uri() }

__PACKAGE__->meta()->make_immutable();

1;

__END__
