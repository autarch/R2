package R2::Web::Form::Report::TopDonors;

use Moose;
use Chloro;

use namespace::autoclean;

use R2::Types qw( Date PosOrZeroInt );

field start_date => (
    isa       => Date,
    extractor => '_datetime_from_str',
);

field limit => (
    isa     => PosOrZeroInt,
    default => 20,
);

with 'R2::Role::Web::Form', 'R2::Role::Web::Form::StartAndEndDates';

__PACKAGE__->meta()->make_immutable();

1;
