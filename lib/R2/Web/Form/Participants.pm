package R2::Web::Form::Participants;

use strict;
use warnings;
use namespace::autoclean;

use HTML::FormHandler::Moose;

extends 'HTML::FormHandler';

with 'R2::Role::Web::Form';

has_field participation_type_id => (
    type     => 'PosInteger',
    required => 1,
);

has_field description => (
    type => 'Text',
);

has_field start_date => (
    type     => 'Date',
    required => 1,
);

has_field end_date => (
    type => 'Date',
);

has_field participants => (
    type     => 'TextArea',
    required => 1,
);

has_field contact_id => (
    type => 'Checkbox',
);

__PACKAGE__->meta()->make_immutable();

1;
