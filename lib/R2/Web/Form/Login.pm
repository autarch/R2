package R2::Web::Form::Login;

use strict;
use warnings;

use Chloro;
use Chloro::FieldTypes qw( :all );

fieldset 'Your login info';

field username =>
    ( type      => NonEmptyStr,
      required  => 1,
      render_as => 'text',
    );

field password =>
    ( type      => NonEmptyStr,
      required  => 1,
      render_as => 'password',
    );

field remember_me =>
    ( type      => Bool,
      render_as => 'checkbox',
    );

field return_to =>
    ( type      => NonEmptyStr,
      render_as => 'hidden',
    );

no Chloro;

__PACKAGE__->meta()->make_immutable();

1;
