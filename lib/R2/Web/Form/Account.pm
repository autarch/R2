package R2::Web::Form::Account;

use namespace::autoclean;

use Moose;
use Chloro;

use R2::Types qw( Bool DatabaseId MonthAsNumber NonEmptyStr );

with 'R2::Role::Web::Form';

with 'R2::Role::Web::Form::FromSchema' => {
    classes => ['R2::Schema::Account'],
    skip    => [ 'creation_datetime', 'domain_id' ],
};

field domain_id => (
    isa       => DatabaseId,
    extractor => '_extract_domain_id',
);

sub _extract_domain_id {
    my $self = shift;

    return unless $self->user()->is_system_admin();

    return $self->_extract_field_value(@_);
}

__PACKAGE__->meta()->make_immutable();

1;
