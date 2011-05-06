package R2::Web::Form::Person;

use namespace::autoclean;

use Moose;
use Chloro;

use R2::Role::Web::ResultSet::FromSchema;
use R2::Role::Web::ResultSet::NewAndExistingGroups;
use R2::Schema;
use R2::Types qw( Bool );

with 'R2::Role::Web::Form';

with 'R2::Role::Web::Form::FromSchema' => {
    classes => [ 'R2::Schema::Person', 'R2::Schema::Contact' ],
    skip    => [
        qw( contact_id
            contact_type
            email_opt_out
            allows_mail
            allows_phone
            person_id
            creation_datetime
            image_file_id
            account_id
         )
    ],
};

with qw(
    R2::Role::Web::Form::ContactEmailOptOut
    R2::Role::Web::Form::ContactImage
    R2::Role::Web::Form::ContactNote
    R2::Role::Web::Form::EmailAddressGroup
    R2::Role::Web::Form::PhoneNumberGroup
    R2::Role::Web::Form::AddressGroup
    R2::Role::Web::Form::InstantMessagingGroup
    R2::Role::Web::Form::WebsiteGroup
);

{
    my $Class = Moose::Meta::Class->create_anon_class(
        superclasses => ['Chloro::ResultSet'],
        roles        => [
            # XXX - hackaround for bug in Moose::Util::apply_all_roles - it
            # calls mkoptlist which interprets every other role object as a
            # param list or something.
            map { $_, {} }
                R2::Role::Web::ResultSet::FromSchema->meta()->generate_role(
                parameters => {
                    classes =>
                        [ 'R2::Schema::Person', 'R2::Schema::Contact' ],
                    method => 'contact_params',
                },
                ),
            map {
                R2::Role::Web::ResultSet::NewAndExistingGroups->meta()
                    ->generate_role( parameters => { group => $_ } )
                } qw( phone_number email_address address messaging_provider website )
        ],
        weaken => 0,
    );

    $Class->make_immutable();

    sub _resultset_class { $Class->name() }
}

1;

