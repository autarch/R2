package R2::Schema::Tag;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with 'R2::Role::Schema::URIMaker';

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
        . $self->tag_id();
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
