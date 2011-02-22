package R2::Schema::SavedSearch;

use strict;
use warnings;
use namespace::autoclean;

use JSON;
use R2::Schema;
use R2::Schema::Account;
use URI::Escape qw( uri_escape_utf8 );

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('SavedSearch') );

    has_one( $schema->table('User') );

    my $json = JSON->new()->utf8()->convert_blessed();

    #<<<
    transform params
        => inflate { $json->decode( $_[1] ) }
        => deflate { $json->encode( $_[1] ) };
    #>>>
}

has search_object => (
    is       => 'ro',
    does     => 'R2::Role::Search',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_search_object',
);

sub _build_search_object {
    my $self = shift;

    my %p = %{ $self->params() };
    $p{account}
        = R2::Schema::Account->new( account_id => $p{account}{account_id} );

    $self->class()->new(%p);
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
