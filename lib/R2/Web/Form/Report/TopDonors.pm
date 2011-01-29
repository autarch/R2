package R2::Web::Form::Report::TopDonors;

use strict;
use warnings;
use namespace::autoclean;

use HTML::FormHandler::Moose;

extends 'HTML::FormHandler';

with 'R2::Role::Web::Form';

has_field start_date => (
    type  => 'Date',
    label => 'Start date',
);

has_field end_date => (
    type  => 'Date',
    label => 'End date',
);

has_field limit => (
    type    => 'Integer',
    label   => 'Max donors',
    default => 20,
);

__PACKAGE__->meta()->make_immutable();

1;
