package R2::Schema::Tag;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema;
use R2::Types qw( Bool );
use URI::Escape qw( uri_escape_utf8 );

use Fey::ORM::Table;

with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Tag') );

    has_one( $schema->table('Account') );

    has_one email_list => (
        table => $schema->table('EmailList'),
        undef => 1,
    );

    has is_email_list => (
        is       => 'ro',
        isa      => Bool,
        init_arg => undef,
        lazy     => 1,
        default  => sub { $_[0]->email_list() ? 1 : 0 },
    );
}

with 'R2::Role::Schema::Serializes' => { add => ['is_email_list'] };

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
