package R2::Schema::Tag;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema;
use URI::Escape qw( uri_escape_utf8 );

use Fey::ORM::Table;

with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Tag') );

    has_one( $schema->table('Account') );
}

with 'R2::Role::Schema::Serializes';

sub _base_uri_path {
    my $self = shift;

    return
          $self->account()->_base_uri_path()
        . '/tag/'
        . uri_escape_utf8( $self->tag() );
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
