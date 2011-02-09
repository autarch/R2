package R2::Controller::Account;

use strict;
use warnings;
use namespace::autoclean;

use List::AllUtils qw( any );
use R2::Schema::Account;
use R2::Schema::CustomFieldGroup;
use R2::Web::Form::Report::TopDonors;
use R2::Util qw( string_is_empty );

use Moose;
use CatalystX::Routes;

BEGIN { extends 'R2::Controller::Base' }

chain_point _set_account
    => chained '/'
    => path_part 'account'
    => capture_args 1
    => sub {
    my $self       = shift;
    my $c          = shift;
    my $account_id = shift;

    my $account = R2::Schema::Account->new( account_id => $account_id );

    $c->redirect_and_detach( $c->domain()->application_uri( path => q{} ) )
        unless $account;

    $self->_check_authz(
        $c,
        'can_view_account',
        { account => $c->account() },
        'You are not authorized to view this account',
        $c->domain()->application_uri( path => q{} ),
    );

    unless ( uc $c->request()->method() eq 'GET' ) {
        $self->_check_authz(
            $c,
            'can_edit_account',
            { account => $c->account() },
            'You are not authorized to edit this account',
            $c->domain()->application_uri( path => q{} ),
        );
    }

    $c->stash()->{account} = $account;
};

get_html q{}
    => chained '_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $c->tabs()->by_id('Dashboard')->set_is_selected(1);

    $self->_add_basic_sidebar($c);

    $c->stash()->{template} = '/dashboard';
};

sub _add_basic_sidebar {
    my $self = shift;
    my $c    = shift;

    $c->sidebar()->add_item('contact-search');
    $c->sidebar()->add_item('add-contacts');
}

put q{}
    => chained '_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my %p = $c->request()->account_params();
    delete $p{domain_id}
        unless $c->user()->is_system_admin();

    my $account = $c->stash()->{account};

    eval { $account->update(%p) };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error     => $e,
            uri       => $account->uri( view => 'edit_form' ),
            form_data => $c->request()->params(),
        );
    }

    $c->session_object()
        ->add_message(
        'The ' . $account->name() . ' account has been updated' );

    $c->redirect_and_detach( $account->uri( view => 'settings' ) );
};

{
    my @paths = qw(
        settings
        edit_form
        donation_settings
        donation_sources_form
        donation_campaigns_form
        payment_types_form
        address_types_form
        phone_number_types_form
        contact_note_types_form
        custom_field_groups_form
        users
        new_user_form
    );

    for my $path (@paths) {
        my $template = '/account/' . $path;

        get_html $path
            => chained '_set_account'
            => args 0
            => sub {
                my $self = shift;
                my $c    = shift;

                $self->_check_authz(
                    $c,
                    'can_edit_account',
                    { account => $c->account() },
                    'You are not authorized to edit this account',
                    $c->domain()->application_uri( path => q{} ),
                );

                my $params = $c->request()->params();
                $c->stash()->{$_} = $params->{$_} for keys %{$params};

                $c->stash()->{template} = $template;
            };
    }
}

post donation_sources
    => chained '_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->donation_sources();

    eval { $account->update_or_add_donation_sources( $existing, $new ); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error     => $e,
            uri       => $account->uri( view => 'donation_sources_form' ),
            form_data => $c->request()->params(),
        );
    }

    $c->session_object()
        ->add_message( 'The donation sources for '
            . $account->name()
            . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'donation_sources_form' ) );
};

post donation_campaigns
    => chained '_set_account'
    => args 0
    => sub  {
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->donation_campaigns();

    eval { $account->update_or_add_donation_campaigns( $existing, $new ); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error     => $e,
            uri       => $account->uri( view => 'donation_campaigns_form' ),
            form_data => $c->request()->params(),
        );
    }

    $c->session_object()
        ->add_message( 'The donation campaigns for '
            . $account->name()
            . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'donation_campaigns_form' ) );
};

post payment_types
    => chained '_set_account'
    => args 0
    => sub  {
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->payment_types();

    eval { $account->update_or_add_payment_types( $existing, $new ); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error     => $e,
            uri       => $account->uri( view => 'payment_types_form' ),
            form_data => $c->request()->params(),
        );
    }

    $c->session_object()
        ->add_message(
        'The payment types for ' . $account->name() . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'payment_types_form' ) );
};

post address_types
    => chained '_set_account'
    => args 0
    => sub  {
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->address_types();

    eval { $account->update_or_add_address_types( $existing, $new ); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error     => $e,
            uri       => $account->uri( view => 'address_types_form' ),
            form_data => $c->request()->params(),
        );
    }

    $c->session_object()
        ->add_message(
        'The address types for ' . $account->name() . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'address_types_form' ) );
};

post phone_number_types
    => chained '_set_account'
    => args 0
    => sub  {
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->phone_number_types();

    eval { $account->update_or_add_phone_number_types( $existing, $new ); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error     => $e,
            uri       => $account->uri( view => 'phone_number_types_form' ),
            form_data => $c->request()->params(),
        );
    }

    $c->session_object()
        ->add_message( 'The phone number types for '
            . $account->name()
            . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'phone_number_types_form' ) );
};

post contact_note_types
    => chained '_set_account'
    => args 0
    => sub  {
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->contact_note_types();

    eval { $account->update_or_add_contact_note_types( $existing, $new ); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error     => $e,
            uri       => $account->uri( view => 'contact_note_types_form' ),
            form_data => $c->request()->params(),
        );
    }

    $c->session_object()
        ->add_message( 'The contact history types for '
            . $account->name()
            . ' have been updated' );

    $c->redirect_and_detach( $account->uri( view => 'contact_note_types_form' ) );
};

post custom_field_groups
    => chained '_set_account'
    => args 0
    => sub  {
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my ( $existing, $new ) = $c->request()->custom_field_groups();

    eval { $account->update_or_add_custom_field_groups( $existing, $new ); };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error     => $e,
            uri       => $account->uri( view => 'custom_field_groups_form' ),
            form_data => $c->request()->params(),
        );
    }

    $c->session_object()
        ->add_message( 'The custom field groups for '
            . $account->name()
            . ' have been updated' );

    $c->redirect_and_detach(
        $account->uri( view => 'custom_field_groups_form' ) );
};

chain_point _set_custom_field_group
    => chained '_set_account'
    => path_part 'custom_field_group'
    => capture_args 1
    => sub {
    my $self                  = shift;
    my $c                     = shift;
    my $custom_field_group_id = shift;

    my $group = R2::Schema::CustomFieldGroup->new(
        custom_field_group_id => $custom_field_group_id );

    $c->redirect_and_detach( $c->domain()->application_uri( path => q{} ) )
        unless $group;

    $c->stash()->{group} = $group;
};

get_html q{}
    => chained '_set_custom_field_group'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/account/custom_field_group';
};

post q{}
    => chained '_set_custom_field_group'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my ( $existing, $new ) = $c->request()->custom_fields();

    my $group = $c->stash()->{group};

    eval { $group->update_or_add_custom_fields( $existing, $new ); };

    my $account = $c->stash()->{account};

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error => $e,
            uri   => $account->uri(
                view => 'custom_field_group/'
                    . $group->custom_field_group_id()
            ),
            form_data => $c->request()->params(),
        );
    }

    $c->session_object()
        ->add_message(
        'The custom fields for ' . $group->name() . ' have been updated' );

    $c->redirect_and_detach(
        $account->uri( view => 'custom_field_groups_form' ) );
};

post user
    => chained '_set_account'
    => args 0
    => sub  {
    my $self = shift;
    my $c    = shift;

    my %p = $c->request()->user_params();
    delete $p{is_system_admin}
        unless $c->user()->is_system_admin();

    delete @p{ 'password', 'password2' }
        unless any { !string_is_empty($_) } @p{ 'password', 'password2' };

    my @errors;

    my $password2 = $c->request()->params()->{password2};

    unless ( ( $p{password} // q{} ) eq ( $password2 // q{} ) ) {
        push @errors, 'The two passwords you provided did not match.';
    }

    my $account = $c->account();

    my $user;

    unless (@errors) {
        delete $p{password2};

        $p{account_id} = $account->account_id();

        $user = eval { R2::Schema::User->insert( %p, user => $c->user() ) };

        push @errors, $@
            if $@;
    }

    if (@errors) {
        my $e = R2::Exception::DataValidation->new( errors => \@errors );

        $c->redirect_with_error(
            error     => $e,
            uri       => $account->uri( view => 'new_user_form' ),
            form_data => $c->request()->params(),
        );
    }

    $c->session_object()
        ->add_message(
        $user->display_name() . '  has been added to this account' );

    $c->redirect_and_detach( $account->uri( view => 'users' ) );
};

get_html 'tags'
    => chained '_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $c->tabs()->by_id('Tags')->set_is_selected(1);

    $self->_add_basic_sidebar($c);

    $c->stash()->{tags} = $c->stash()->{account}->tags();

    $c->stash()->{template} = '/account/tags';
};

chain_point _set_tag
    => chained '_set_account'
    => path_part 'tag'
    => capture_args 1
    => sub {
    my $self     = shift;
    my $c        = shift;
    my $tag_name = shift;

    my $account = $c->stash()->{account};
    my $tag     = R2::Schema::Tag->new(
        account_id => $account->account_id(),
        tag        => $tag_name,
    );

    $c->redirect_and_detach( $c->domain()->application_uri( path => q{} ) )
        unless $tag;

    $c->stash()->{tag} = $tag;
};

get_html q{}
    => chained '_set_tag'
    => args 0
    => sub {
    my $self     = shift;
    my $c        = shift;

    $c->tabs()->by_id('Tags')->set_is_selected(1);

    $self->_add_basic_sidebar($c);

    $c->stash()->{template} = '/tag/view';
};

del q{}
    => chained '_set_tag'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{tag}->delete();

    $self->status_no_content(
        $c,
        location => $c->stash()->{account}->uri( view => 'tags' )
    );
};

get_html 'reports'
    => chained '_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $c->tabs()->by_id('Reports')->set_is_selected(1);

    $self->_add_basic_sidebar($c);

    $c->stash()->{template} = '/account/reports';
};

get_html 'top_donors'
    => chained '_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $c->tabs()->by_id('Reports')->set_is_selected(1);

    my $form = R2::Web::Form::Report::TopDonors->new( user => $c->user() );
    $form->process(
        action => $c->account()->uri( view => 'top_donors' ),
        params => $c->request()->params(),
    );

    # XXX - form validation errors

    my $form_val = $form->value();

    $c->stash()->{donors} = $c->account()->top_donors($form_val);

    $c->stash()->{form} = $form;

    $c->stash()->{template} = '/account/top_donors';
};

__PACKAGE__->meta()->make_immutable();

1;
