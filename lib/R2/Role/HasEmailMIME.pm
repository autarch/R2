package R2::Role::HasEmailMIME;

use namespace::autoclean;

use Moose::Role;

use R2::Types qw( Maybe );

has mime_object => (
    is      => 'ro',
    isa     => 'Email::MIME',
    lazy    => 1,
    default => sub { Email::MIME->new( $_[0]->raw_content() ) },
);

has _plain_body_part => (
    is      => 'ro',
    isa     => Maybe ['Email::MIME'],
    lazy    => 1,
    builder => '_build_plain_body_part',
);

has _html_body_part => (
    is      => 'ro',
    isa     => Maybe ['Email::MIME'],
    lazy    => 1,
    builder => '_build_html_body_part',
);

sub _build_plain_body_part {
    my $self = shift;

    return $self->_first_part_with_type('text/plain');
}

sub _build_html_body_part {
    my $self = shift;

    return $self->_first_part_with_type('text/html');
}

sub _first_part_with_type {
    my $self = shift;
    my $type = shift;

    my $first;

    local $@;
    eval {
        $self->mime_object()->walk_parts(
            sub {
                my $part = shift;

                if ( $part->content_type() =~ /^\Q$type\E(?:;|$)/ ) {
                    $first = $part;
                    die;
                }
            }
        );
    };

    return $first;
}

{
    package Email::MIME;

    no warnings 'redefine';

    # The version in Email::MIME resets the subparts after every walk, which
    # is hugely inefficient.
    sub walk_parts {
        my ( $self, $callback ) = @_;

        my $walk;
        $walk = sub {
            my ($part) = @_;
            $callback->($part);

            $walk->($_) for $part->subparts;
        };

        my $rv = $walk->($self);

        undef $walk;

        return $rv;
    }
}

1;
