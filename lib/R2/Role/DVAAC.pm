package R2::Role::DVAAC;

use strict;
use warnings;

# This role exists solely to combine DataValidtor and ActsAsContact
# _in the correct order_, so that data validation happens _first_.

use Moose::Role;

with 'R2::Role::ActsAsContact';
with 'R2::Role::DataValidator' => { excludes => '_validation_errors' };

no Moose::Role;

1;
