package R2::Search::Plugin::Email::ByContactId;

use Moose;
# intentionally not StrictConstructor

use namespace::autoclean;

use R2::Schema;
use R2::Types qw( DatabaseId );

with 'R2::Role::Search::Plugin';

has contact_id => (
    is       => 'ro',
    isa      => DatabaseId,
    required => 1,
);

my $Schema = R2::Schema->Schema();

sub apply_where_clauses {
    my $self   = shift;
    my $select = shift;

    $select->where(
        $Schema->table('Email')->column('contact_id'),
        '=',
        $self->contact_id()
    );

    return;
}

sub uri_parameters {
    my $self = shift;

    return ( contact_id => $self->contact_id() );
}

# XXX - not sure if this will be needed
sub _build_description {
    my $self = shift;

    return q{};
}

__PACKAGE__->meta()->make_immutable();

1;
