package R2::Controller::Account;

use strict;
use warnings;

use R2::Schema::Account;
use R2::Schema::CustomFieldGroup;

use Moose;

BEGIN { extends 'R2::Controller::Base' }


sub _set_account : Chained('/') : PathPart('account') : CaptureArgs(1)
{
    my $self       = shift;
    my $c          = shift;
    my $account_id = shift;

    my $account = R2::Schema::Account->new( account_id => $account_id );

    $c->redirect_and_detach( $c->domain()->application_uri( path => q{} ) )
        unless $account;

    unless ( $c->model('Authz')->user_can_view_account( user    => $c->user(),
                                                        account => $account,
                                                      ) )
    {
        $c->redirect_with_error
            ( error => 'You are not authorized to view this account',
              uri   => $c->domain()->application_uri( path => q{} ),
            );
    }

    unless ( uc $c->request()->method() eq 'GET'
             ||
             $c->model('Authz')->user_can_edit_account( user    => $c->user(),
                                                        account => $account,
                                                      ) )
    {
        $c->redirect_with_error
            ( error => 'You are not authorized to edit this account',
              uri   => $c->domain()->application_uri( path => q{} ),
            );
    }

    $c->stash()->{account} = $account;
}

sub account : Chained('_set_account') : PathPart('') : Args(0) : ActionClass('+R2::Action::REST') { }

sub account_GET_html : Private
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/dashboard';
}

sub account_PUT : Private
{
    my $self = shift;
    my $c    = shift;

    my %p = $c->request()->account_params();
    delete $p{domain_id}
        unless $c->user()->is_system_admin();

    my $account = $c->stash()->{account};

    eval { $account->update(%p) };

    if ( my $e = $@ )
    {
        $c->redirect_with_error
            ( error     => $e,
              uri       => $account->uri( view => 'edit_form' ),
              form_data => $c->request()->params(),
            );
    }

    $c->session_object()->add_message( 'The ' . $account->name() . ' account has been updated' );

    $c->redirect_and_detach( $account->uri( view => 'settings' ) );
}

sub settings : Chained('_set_account') : PathPart('settings') : Args(0) { }

sub edit_form : Chained('_set_account') : PathPart('edit_form') : Args(0) { }

sub donation_settings : Chained('_set_account') : PathPart('donation_settings') : Args(0) { }

sub donation_sources_form : Chained('_set_account') : PathPart('donation_sources_form') : Args(0) { }

sub donation_source : Chained('_set_account') : PathPart('donation_source') : Args(0) : ActionClass('+R2::Action::REST') { }

sub donation_source_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->donation_sources();

    eval
    {
        $account->update_or_add_donation_sources( $existing, $new );
    };

    if ( my $e = $@ )
    {
        $c->redirect_with_error
            ( error     => $e,
              uri       => $account->uri( view => 'donation_sources_form' ),
              form_data => $c->request()->params(),
            );
    }

    $c->session_object()->add_message( 'The donation sources for ' . $account->name() . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'donation_settings' ) );
}

sub donation_targets_form : Chained('_set_account') : PathPart('donation_targets_form') : Args(0) { }

sub donation_target : Chained('_set_account') : PathPart('donation_target') : Args(0) : ActionClass('+R2::Action::REST') { }

sub donation_target_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->donation_targets();

    eval
    {
        $account->update_or_add_donation_targets( $existing, $new );
    };

    if ( my $e = $@ )
    {
        $c->redirect_with_error
            ( error     => $e,
              uri       => $account->uri( view => 'donation_targets_form' ),
              form_data => $c->request()->params(),
            );
    }

    $c->session_object()->add_message( 'The donation targets for ' . $account->name() . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'donation_settings' ) );
}

sub payment_types_form : Chained('_set_account') : PathPart('payment_types_form') : Args(0) { }

sub payment_type : Chained('_set_account') : PathPart('payment_type') : Args(0) : ActionClass('+R2::Action::REST') { }

sub payment_type_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->payment_types();

    eval
    {
        $account->update_or_add_payment_types( $existing, $new );
    };

    if ( my $e = $@ )
    {
        $c->redirect_with_error
            ( error     => $e,
              uri       => $account->uri( view => 'payment_types_form' ),
              form_data => $c->request()->params(),
            );
    }

    $c->session_object()->add_message( 'The payment types for ' . $account->name() . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'donation_settings' ) );
}

sub address_types_form : Chained('_set_account') : PathPart('address_types_form') : Args(0) { }

sub address_type : Chained('_set_account') : PathPart('address_type') : Args(0) : ActionClass('+R2::Action::REST') { }

sub address_type_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->address_types();

    eval
    {
        $account->update_or_add_address_types( $existing, $new );
    };

    if ( my $e = $@ )
    {
        $c->redirect_with_error
            ( error     => $e,
              uri       => $account->uri( view => 'address_types_form' ),
              form_data => $c->request()->params(),
            );
    }

    $c->session_object()->add_message( 'The address types for ' . $account->name() . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'settings' ) );
}

sub countries_form : Chained('_set_account') : PathPart('countries_form') : Args(0) { }

sub country : Chained('_set_account') : PathPart('country') : Args(0) : ActionClass('+R2::Action::REST') { }

sub country_POST : Private
{
    my $self = shift;
    my $c    = shift;

}

sub phone_number_types_form : Chained('_set_account') : PathPart('phone_number_types_form') : Args(0) { }

sub phone_number_type : Chained('_set_account') : PathPart('phone_number_type') : Args(0) : ActionClass('+R2::Action::REST') { }

sub phone_number_type_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->phone_number_types();

    eval
    {
        $account->update_or_add_phone_number_types( $existing, $new );
    };

    if ( my $e = $@ )
    {
        $c->redirect_with_error
            ( error     => $e,
              uri       => $account->uri( view => 'phone_number_types_form' ),
              form_data => $c->request()->params(),
            );
    }

    $c->session_object()->add_message( 'The phone number types for ' . $account->name() . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'settings' ) );
}

sub contact_note_types_form : Chained('_set_account') : PathPart('contact_note_types_form') : Args(0) { }

sub contact_note_type : Chained('_set_account') : PathPart('contact_note_type') : Args(0) : ActionClass('+R2::Action::REST') { }

sub contact_note_type_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->contact_note_types();

    eval
    {
        $account->update_or_add_contact_note_types( $existing, $new );
    };

    if ( my $e = $@ )
    {
        $c->redirect_with_error
            ( error     => $e,
              uri       => $account->uri( view => 'contact_note_types_form' ),
              form_data => $c->request()->params(),
            );
    }

    $c->session_object()->add_message( 'The contact history types for ' . $account->name() . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'settings' ) );
}

sub messaging_providers_form : Chained('_set_account') : PathPart('messaging_providers_form') : Args(0) { }

sub messaging_provider : Chained('_set_account') : PathPart('messaging_provider') : Args(0) : ActionClass('+R2::Action::REST') { }

sub messaging_provider_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->messaging_providers();

    eval
    {
        $account->update_or_add_messaging_providers( $existing, $new );
    };

    if ( my $e = $@ )
    {
        $c->redirect_with_error
            ( error     => $e,
              uri       => $account->uri( view => 'messaging_providers_form' ),
              form_data => $c->request()->params(),
            );
    }

    $c->session_object()->add_message( 'The instant messaging providers for ' . $account->name() . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'settings' ) );
}

sub custom_field_groups_form : Chained('_set_account') : PathPart('custom_field_groups_form') : Args(0) { }

sub custom_field_group_collection : Chained('_set_account') : PathPart('custom_field_group') : Args(0) : ActionClass('+R2::Action::REST') { }

sub custom_field_group_collection_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->custom_field_groups();

    eval
    {
        $account->update_or_add_custom_field_groups( $existing, $new );
    };

    if ( my $e = $@ )
    {
        $c->redirect_with_error
            ( error     => $e,
              uri       => $account->uri( view => 'custom_field_groups_form' ),
              form_data => $c->request()->params(),
            );
    }

    $c->session_object()->add_message( 'The custom field groups for ' . $account->name() . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'custom_field_groups_form' ) );
}

sub _set_custom_field_group : Chained('_set_account') : PathPart('custom_field_group') : CaptureArgs(1)
{
    my $self                  = shift;
    my $c                     = shift;
    my $custom_field_group_id = shift;

    my $group = R2::Schema::CustomFieldGroup->new( custom_field_group_id => $custom_field_group_id );

    $c->redirect_and_detach( $c->domain()->application_uri( path => q{} ) )
        unless $group;

    $c->stash()->{group} = $group;
}

sub custom_field_group : Chained('_set_custom_field_group') : PathPart('') : Args(0) : ActionClass('+R2::Action::REST') { }

sub custom_field_group_GET_html : Private
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/account/custom_field_group';
}

sub custom_field_group_POST : Private
{
    my $self = shift;
    my $c    = shift;

    my ( $existing, $new ) = $c->request()->custom_fields();

    my $group = $c->stash()->{group};

    eval
    {
        $group->update_or_add_custom_fields( $existing, $new );
    };

    my $account = $c->stash()->{account};

    if ( my $e = $@ )
    {
        $c->redirect_with_error
            ( error     => $e,
              uri       => $account->uri( view => 'custom_field_group/' . $group->custom_field_group_id() ),
              form_data => $c->request()->params(),
            );
    }

    $c->session_object()->add_message( 'The custom fields for ' . $group->name() . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'custom_field_groups_form' ) );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
