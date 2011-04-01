package R2::Role::Web::Form;

use Moose::Role;

use namespace::autoclean;

use DateTime::Format::Natural;
use R2::Util qw( string_is_empty );

has user => (
    is       => 'ro',
    isa      => 'R2::Schema::User',
    required => 1,
);

my $parser = DateTime::Format::Natural->new();

sub _datetime_from_str {
    my $self = shift;

    my $value = $self->extract_field_value(@_);

    return unless $value;

    return $parser->parse_datetime($value);
}

1;
