package R2::Schema::Domain;

use strict;
use warnings;

use R2::Schema::Account;
use R2::Schema;
use R2::Types;
use R2::Util qw( string_is_empty );
use URI::FromHash ();

use Fey::ORM::Table;
use MooseX::Params::Validate qw( validate );

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Domain') );

    has_many 'accounts' =>
        ( table => $schema->table('Account') );
}

has '_uri_scheme' =>
    ( is      => 'ro',
      isa     => 'Str',
      lazy    => 1,
      default => sub { $_[0]->requires_ssl() ? 'https' : 'http' },
    );


{
    my %spec = ( path     => { isa      => 'R2::Type::URIPath' },
                 query    => { isa      => 'HashRef',
                               default  => {},
                             },
                 fragment => { isa      => 'Str',
                               optional => 1,
                             },
               );
    sub uri
    {
        my ( $self, %p ) = validate( \@_, %spec );

        return URI::FromHash::uri( scheme => $self->_uri_scheme(),
                                   host   => $self->web_hostname(),
                                   %p,
                                 );
    }
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
