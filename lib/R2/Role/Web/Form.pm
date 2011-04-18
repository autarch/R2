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

sub _build_human_name {
    my $self = shift;

    my $name = $self->name();
    $name =~ s/_/ /g;

    return ucfirst $name;
}

sub _datetime_from_str {
    my $self = shift;

    my $value = $self->_extract_field_value(@_);

    return unless $value;

    my $dt = $parser->parse_datetime($value);

    return $dt if $parser->success();

    return;
}

1;
