package R2::Web::Form::Participants;

use Moose;
use Chloro;

use namespace::autoclean;

use R2::Types qw( ArrayRef Date NonEmptySimpleStr NonEmptyStr PositiveInt );

with 'R2::Role::Web::Form';

field participation_type_id => (
    isa      => PositiveInt,
    required => 1,
);

field description => (
    isa => NonEmptyStr,
);

field start_date => (
    isa       => Date,
    required  => 1,
    extractor => '_datetime_from_str',
);

field end_date => (
    isa       => Date,
    extractor => '_datetime_from_str',
    validator => '_validate_end_date',
);

field participants => (
    isa => ArrayRef [NonEmptySimpleStr],
    extractor => '_extract_participants',
);

field contact_id => (
    isa => ArrayRef [PositiveInt],
);

sub _validate_end_date {
    my $self = shift;
    my $end = shift;

    return unless defined $end;

    my $start = $self->_datetime_from_str(@_);

    return if $start <= $end;

    return 'The end date must come after the start date.';
}

sub _extract_participants {
    my $self = shift;

    my $value = $self->extract_field_value(@_);

    return $value if ref $value;

    return [ split /[\r\n]+/, $value ];
}

__PACKAGE__->meta()->make_immutable();

1;
