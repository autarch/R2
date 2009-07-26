package R2::Web::Form::Donation;

use strict;
use warnings;

use Chloro;
use Chloro::FieldTypes qw( PosNumber );
use R2::Web::Form::FieldTypes qw( Date );

fieldset 'Add a new donation';

field amount =>
    ( type       => PosNumber,
      required   => 1,
      render_as  => 'text',
      html_class => 'narrow',
      help_text  => 'Enter an amount in dollars and cents (50, 9.22).',
    );

field value_for_donor =>
    ( type       => PosNumber,
      required   => 1,
      render_as  => 'text',
      html_class => 'narrow',
      help_text  => 'If the donor received a gift in return for this donation, enter the value of the gift here.',
    );

field transaction_cost =>
    ( type       => PosNumber,
      required   => 1,
      render_as  => 'text',
      html_class => 'narrow',
      help_text  => 'If your organization did not receive the full amount donated, enter the transaction cost here.',
    );

field donation_date =>
    ( type       => Date,
      required   => 1,
      render_as  => 'text',
      html_class => 'narrow',
      help_text  => 'If your organization did not receive the full amount donated, enter the transaction cost here.',
    );


no Chloro;

__PACKAGE__->meta()->make_immutable();

1;
