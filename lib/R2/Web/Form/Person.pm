package R2::Web::Form::Person;

use Moose;
use Chloro;

use R2::Role::Web::ResultSet::NewAndExistingGroups;
use R2::Schema;
use R2::Types qw( Bool );

with 'R2::Role::Web::Form';

with 'R2::Role::Web::Form::FromSchema' => {
    classes => [ 'R2::Schema::Person' ],
    skip    => [qw( contact_type email_opt_out )],
};

with qw(
    R2::Role::Web::Form::EmailAddressGroup
    R2::Role::Web::Form::WebsiteGroup
    R2::Role::Web::Form::InstantMessagingGroup
    R2::Role::Web::Form::PhoneNumberGroup
    R2::Role::Web::Form::AddressGroup
);

field email_opt_out => (
    isa       => Bool,
    extractor => '_extract_email_opt_out',
);

sub _extract_email_opt_out {
    my $self = shift;

    return unless $self->user()->is_system_admin();

    return $self->_extract_field_value(@_);
}

{
    my $Class = Moose::Meta::Class->create_anon_class(
        superclasses => ['Chloro::ResultSet'],
        roles        => [
            map {
                R2::Role::Web::ResultSet::NewAndExistingGroups->meta()
                    ->generate_role( parameters => { group => $_ } )
                } qw( email_address website messaging_provider phone_number address )
        ],
        cache => 1,
    );

    $Class->make_immutable();

    sub _resultset_class { $Class->name() }
}

1;

