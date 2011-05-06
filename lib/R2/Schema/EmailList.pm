package R2::Schema::EmailList;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema;

use Fey::ORM::Table;

with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('EmailList') );

    has_one( $schema->table('Tag') );
}

sub _base_uri_path {
    my $self = shift;

    return
          $self->tag()->account()->_base_uri_path()
        . '/email_list/'
        . $self->tag_id();
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
