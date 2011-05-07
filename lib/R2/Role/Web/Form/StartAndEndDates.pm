package R2::Role::Web::Form::StartAndEndDates;

use Moose::Role;
use Chloro;

use namespace::autoclean;

use R2::Types qw( Date );

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

sub _validate_end_date {
    my $self = shift;
    my $end  = shift;

    return unless defined $end;

    my ($start) = $self->_datetime_from_str(@_);

    return if $start && $start <= $end;

    return 'The end date must come after the start date.';
}

1;
