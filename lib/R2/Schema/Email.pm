package R2::Schema::Email;

use strict;
use warnings;
use namespace::autoclean;

use Email::MIME;
use R2::Schema;

use Fey::ORM::Table;

with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Email') );

    has_one from_contact => ( table => $schema->table('Contact') );

    has_one from_user => ( table => $schema->table('User') );
}

has email => (
    is      => 'ro',
    isa     => 'Email::MIME',
    lazy    => 1,
    default => sub { Email::MIME->new( $_[0]->raw_content() ) },
);

with 'R2::Role::Schema::Serializes';

sub _base_uri_path {
    my $self = shift;

    return
          $self->account()->_base_uri_path()
        . '/email/'
        . $self->email_id();
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
