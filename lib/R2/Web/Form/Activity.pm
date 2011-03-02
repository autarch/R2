package R2::Web::Form::Activity;

use strict;
use warnings;
use namespace::autoclean;

use HTML::FormHandler::Moose;

extends 'HTML::FormHandler';

with 'R2::Role::Web::Form';

has_field name => (
    type     => 'Text',
    required => 1,
);

has_field activity_type_id => (
    type     => 'Integer',
    required => 1,
);

has_field is_archived => (
    type    => 'Boolean',
    default => 0,
);

__PACKAGE__->meta()->make_immutable();

1;
