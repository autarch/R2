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

    return $self->_parse_datetime($value);
}

{
    my $parser = DateTime::Format::Natural->new(
        time_zone => 'floating',
    );

    sub _parse_datetime {
        my $self  = shift;
        my $value = shift;

        # DT::F::Natural cannot handle space before am/pm
        $value =~ s/\s+(am|pm)/$1/i;

        my $dt = $parser->parse_datetime($value);

        return $dt if $parser->success();

        return;
    }
}

1;
