package R2::Web::Form::Activity;

use namespace::autoclean;

use Moose;
use Chloro;

with 'R2::Role::Web::Form';

with 'R2::Role::Web::Form::FromSchema' => {
    classes => ['R2::Schema::Activity'],
    skip    => [ 'account_id', 'creation_datetime' ],
};

__PACKAGE__->meta()->make_immutable();

1;
