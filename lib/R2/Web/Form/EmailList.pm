package R2::Web::Form::EmailList;

use Moose;
use Chloro;

use R2::Role::Web::ResultSet::FromSchema;
use R2::Schema;
use R2::Types qw( Bool );

with 'R2::Role::Web::Form';

with 'R2::Role::Web::Form::FromSchema' => {
    classes => ['R2::Schema::EmailList'],
};

1;
