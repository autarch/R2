package R2::Web::Form::Account;

use namespace::autoclean;

use Moose;
use Chloro;

use namespace::autoclean;

use R2::Types qw( Bool DatabaseId MonthAsNumber NonEmptyStr );

with 'R2::Role::Web::Form';

field name => (
    isa        => NonEmptyStr,
    required   => 1,
);

field fiscal_year_start_month => (
    isa      => MonthAsNumber,
    required => 1,
);

field default_time_zone => (
    isa      => NonEmptyStr,
    required => 1,
);

field domain_id => (
    isa => DatabaseId,
);

sub _extract_domain_id {
    my $self = shift;

    return unless $self->user()->is_system_admin();

    return $self->_extract_field_value(@_);
}

__PACKAGE__->meta()->make_immutable();

1;
