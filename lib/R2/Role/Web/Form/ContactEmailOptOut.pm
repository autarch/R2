package R2::Role::Web::Form::ContactEmailOptOut;

use Moose::Role;
use Chloro;

use R2::Types qw( Bool );

field email_opt_out => (
    isa       => Bool,
    extractor => '_extract_email_opt_out',
);

sub _extract_email_opt_out {
    my $self = shift;

    return unless $self->user()->is_system_admin();

    return $self->_extract_field_value(@_);
}

1;
