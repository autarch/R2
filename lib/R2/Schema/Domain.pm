package R2::Schema::Domain;

use strict;
use warnings;

use Moose::Util::TypeConstraints;
use R2::Config;
use R2::Schema::Account;
use R2::Schema;
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
    subtype 'R2::Type::URIPath'
        => as 'Str'
        => where { defined $_ && length $_ && $_ =~ m{^/} }
        => message { my $path = defined $_ ? $_ : '';
                     "This path ($path) is either empty or does not start with a slash (/)" };

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

make_immutable;

no Fey::ORM::Table;
no Moose;
no Moose::Util::TypeConstraints;

1;

__END__
