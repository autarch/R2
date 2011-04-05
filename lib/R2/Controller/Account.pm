package R2::Controller::Account;

use strict;
use warnings;
use namespace::autoclean;

use Lingua::EN::Inflect qw( PL_N );
use List::AllUtils qw( all any );
use R2::Schema::Account;
use R2::Schema::Activity;
use R2::Schema::ContactParticipation;
use R2::Schema::CustomFieldGroup;
use R2::Search::Contact;
use R2::Web::Form::Account;
use R2::Web::Form::Activity;
use R2::Web::Form::DonationCampaigns;
use R2::Web::Form::DonationSources;
use R2::Web::Form::Participants;
use R2::Web::Form::Participation;
use R2::Web::Form::PaymentTypes;
use R2::Web::Form::Report::TopDonors;
use R2::Web::Form::User;
use R2::Util qw( string_is_empty );

use Moose;
use CatalystX::Routes;

extends 'R2::Controller::Base';

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
            'can_edit_account_content',
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

    my $account = $c->stash()->{account};

    my $result = $self->_process_form(
        $c,
        'Account',
        $account->uri( view => 'edit_form' ),
    );

    eval { $account->update( %{ $result->results_as_hash() } ) };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error     => $e,
            uri       => $account->uri( view => 'edit_form' ),
            form_data => $result->secure_results_as_hash(),
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
                    'You are not authorized to manage this account',
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

    my $result = $self->_process_form(
        $c,
        'DonationSources',
        $account->uri( view => 'donation_sources_form' ),
    );

    eval {
        $account->update_or_add_donation_sources(
            $result->existing_donation_sources(),
            $result->new_donation_sources(),
        );
    };

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

    my $result = $self->_process_form(
        $c,
        'DonationCampaigns',
        $account->uri( view => 'donation_campaigns_form' ),
    );

    eval {
        $account->update_or_add_donation_campaigns(
            $result->existing_donation_campaigns(),
            $result->new_donation_campaigns(),
        );
    };

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

    my $result = $self->_process_form(
        $c,
        'PaymentTypes',
        $account->uri( view => 'payment_types_form' ),
    );

    eval {
        $account->update_or_add_payment_types(
            $result->existing_payment_types(),
            $result->new_payment_types(),
        );
    };

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
        unless $group
            && $group->account_id() == $c->stash()->{account}->account_id();

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

    my $account = $c->account();

    my $result = $self->_process_form(
        $c,
        'User',
        $account->uri( view => 'new_user_form' ),
    );

    my $params = $result->results_as_hash();

    delete $params->{is_system_admin}
        unless $c->user()->is_system_admin();

    delete $params->{password2};

    $params->{account_id} = $account->account_id();

    my $user
        = eval { R2::Schema::User->insert( %{$params}, user => $c->user() ) };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error     => $e,
            uri       => $account->uri( view => 'new_user_form' ),
            form_data => $result->secure_results_as_hash(),
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

    my $search = R2::Search::Contact->new(
        account      => $c->stash()->{account},
        restrictions => 'Contact::ByTag',
        tags         => $c->stash()->{tag}->tag(),
    );

    $c->redirect_and_detach( $search->new_uri( with_host => 1 ) );
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

get_html confirm_deletion
    => chained '_set_tag'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'can_edit_account_content',
        { account => $c->account() },
        'You are not authorized to edit this account',
        $c->domain()->application_uri( path => q{} ),
    );

    my $tag = $c->stash()->{tag};

    $c->stash()->{type} = 'tag';
    $c->stash()->{uri}  = $tag->uri();

    my $search = R2::Search::Contact->new(
        account      => $c->stash()->{account},
        restrictions => 'Contact::ByTag',
        tags         => $tag->tag(),
    );

    my $count = $search->count();
    $c->stash()->{extra} = "This tag is currently in use by $count "
        . PL_N( 'contact', $count ) . q{.};

    $c->stash()->{template} = '/shared/confirm_deletion';
};

get_html 'activities'
    => chained '_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $c->tabs()->by_id('Activities')->set_is_selected(1);

    $self->_add_basic_sidebar($c);

    my $include = $c->request()->params()->{include_archived};

    $c->stash()->{activities}
        = $c->stash()->{account}->activities( include_archived => $include );

    $c->stash()->{include_archived} = $include;

    $c->stash()->{template} = '/account/activities';
};

get_html 'new_activity_form'
    => chained '_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'can_edit_account_content',
        { account => $c->account() },
        'You are not authorized to edit this account',
        $c->domain()->application_uri( path => q{} ),
    );

    $c->tabs()->by_id('Activities')->set_is_selected(1);

    $c->stash()->{template} = '/account/activity_form';
};

post 'activities'
    => chained '_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my $account = $c->stash()->{account};

    my $result = $self->_process_form(
        $c,
        'Activity',
        $c->account()->uri( view => 'activities' )
    );

    my $params = $result->results_as_hash();
    $params->{account_id} = $account->account_id();

    my $activity = eval { R2::Schema::Activity->insert( %{$params} ) };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error     => $e,
            uri       => $account->uri( view => 'activities' ),
            form_data => $params,
        );
    }

    $c->session_object()
        ->add_message(
        'The ' . $activity->name() . ' activity has been added' );

    $c->redirect_and_detach( $account->uri( view => 'activities' ) );
};

chain_point _set_activity
    => chained '_set_account'
    => path_part 'activity'
    => capture_args 1
    => sub {
    my $self        = shift;
    my $c           = shift;
    my $activity_id = shift;

    $c->tabs()->by_id('Activities')->set_is_selected(1);

    my $account = $c->stash()->{account};

    my $activity = R2::Schema::Activity->new( activity_id => $activity_id );

    $c->redirect_and_detach( $c->domain()->application_uri( path => q{} ) )
        unless $activity
            && $activity->account_id()
            == $c->stash()->{account}->account_id();

    $c->stash()->{activity} = $activity;
};

get_html 'edit_form'
    => chained '_set_activity'
    => path_part 'edit_form'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'can_edit_account_content',
        { account => $c->account() },
        'You are not authorized to edit this account',
        $c->domain()->application_uri( path => q{} ),
    );

    $c->stash()->{template} = '/account/activity_form';
};

get_html q{}
    => chained '_set_activity'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $self->_add_basic_sidebar($c);

    $c->stash()->{template} = '/activity/view';
};

put q{}
    => chained '_set_activity'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my $activity = $c->stash()->{activity};

    my $params;
    if ( exists $c->request()->params()->{is_archived} ) {
        $params = { is_archived => $c->request()->params()->{is_archived} };
    }
    else {
        my $result = $self->_process_form(
            $c,
            'Activity',
            $activity->uri( view => 'edit_form' ),
        );

        $params = $result->results_as_hash();
    }

    my $message
        = keys %{$params} == 1
        ? (
        $params->{is_archived}
        ? 'has been archived'
        : 'has been unarchived'
        )
        : 'has been updated';

    eval { $activity->update( %{$params} ) };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error     => $e,
            uri       => $activity->uri( view => 'edit_form' ),
            form_data => $params,
        );
    }

    $c->session_object()
        ->add_message(
        'The ' . $activity->name() . ' activity ' . $message );

    my $uri
        = keys %{$params} == 1
        ? $c->stash()->{account}->uri( view => 'activities' )
        : $activity->uri( view => 'edit_form' );

    $c->redirect_and_detach($uri);
};

get_html participants_form
    => chained '_set_activity'
    => path_part 'participants_form'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'can_edit_account_content',
        { account => $c->account() },
        'You are not authorized to edit this account',
        $c->domain()->application_uri( path => q{} ),
    );

    $c->stash()->{template} = '/activity/participants_form';
};

post participants
    => chained '_set_activity'
    => path_part 'participants'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my $activity = $c->stash()->{activity};

    my $result = $self->_process_form(
        $c,
        'Participants',
        $activity->uri( view => 'participants_form' )
    );

    my $params = $result->results_as_hash();

    if ( $params->{contact_id} ) {
        $self->_post_participants( $c, $params );

        return;
    }

    my %contacts;
    for my $name ( @{ $params->{participants} } ) {
        my $search = R2::Search::Person->new(
            account      => $c->stash()->{account},
            restrictions => 'Contact::ByName',
            name         => $name,
            limit        => 0,
        );

        my @matches = $search->contacts()->all();

        if ( @matches != 1 ) {
            my $query = $params;

            $query->{start_date} = $c->user()
                ->format_date_with_year( $query->{start_date} );

            $query->{end_date}
                = $c->user()->format_date_with_year( $query->{end_date} )
                if $query->{end_date};

            $c->redirect_and_detach(
                $activity->uri(
                    view  => 'participants_name_resolution_form',
                    query => $query,
                )
            );
        }

        $contacts{$name} = \@matches;
    }

    $params->{contact_id} = [ map { $_->[0]->contact_id() } values %contacts ];

    $self->_post_participants( $c, $params );
};

sub _post_participants {
    my $self   = shift;
    my $c      = shift;
    my $params = shift;

    delete $params->{participants};

    my $ids = delete $params->{contact_id};

    my $activity = $c->stash()->{activity};

    my %base_vals = %{$params};
    $base_vals{activity_id} = $activity->activity_id();

    eval {
        R2::Schema::ContactParticipation->insert_many(
            map {
                { %base_vals, contact_id => $_ }
                } @{$ids}
        );
    };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error => $e,
            uri =>
                $activity->uri( view => 'participants_form' ),
            form_data => { %{$params}, contact_id => $ids },
        );
    }

    $c->session_object()
        ->add_message( 'The participants have been added to the '
            . $activity->name()
            . ' activity' );

    $c->redirect_and_detach( $activity->uri() );
}

get_html participants_name_resolution_form
    => chained '_set_activity'
    => path_part 'participants_name_resolution_form'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'can_edit_account_content',
        { account => $c->account() },
        'You are not authorized to edit this account',
        $c->domain()->application_uri( path => q{} ),
    );

    my $result = $self->_process_form( $c, 'Participants' );

    my %params = $result->results_hash();

    my $type = R2::Schema::ParticipationType->new(
        participation_type_id => $params{participation_type_id} );

    $c->redirect_and_detach( $c->domain()->application_uri( path => q{} ) )
        unless $type
            && $type->account_id() == $c->stash()->{account}->account_id();

    $c->stash()->{participation_type} = $type;

    $c->stash()->{$_} = $params{$_}
        for qw( description start_date end_date );

    my @contacts;
    for my $name ( @{ $params{participants} } ) {
        my $search = R2::Search::Person->new(
            account      => $c->stash()->{account},
            restrictions => 'Contact::ByName',
            name         => $name,
            limit        => 0,
        );

        my @matches = $search->contacts()->all();

        push @contacts, [ $name, \@matches ];
    }

    $c->stash()->{contacts} = \@contacts;

    $c->stash()->{template} = '/activity/participants_name_resolution_form';
};

chain_point _set_participation
    => chained '_set_activity'
    => path_part 'participation'
    => capture_args 1
    => sub {
    my $self        = shift;
    my $c           = shift;
    my $participation_id = shift;

    my $participation = R2::Schema::ContactParticipation->new(
        contact_participation_id => $participation_id );

    $c->redirect_and_detach( $c->domain()->application_uri( path => q{} ) )
        unless $participation
            && $participation->activity_id()
            == $c->stash()->{activity}->activity_id();

    $c->stash()->{participation} = $participation;

    $c->stash()->{contact} = $participation->contact()->real_contact();
};

get_html participation_edit_form
    => chained '_set_participation'
    => path_part 'edit_form'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'can_edit_account_content',
        { account => $c->account() },
        'You are not authorized to edit this account',
        $c->domain()->application_uri( path => q{} ),
    );

    $c->stash()->{template} = '/activity/participation_edit_form';
};

post q{}
    => chained '_set_participation'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'can_edit_account_content',
        { account => $c->account() },
        'You are not authorized to edit this account',
        $c->domain()->application_uri( path => q{} ),
    );

    my $participation = $c->stash()->{participation};

    my $result = $self->_process_form(
        $c,
        'Participation',
        $participation->uri( view => 'edit_form' )
    );

    eval { $participation->update( $result->results_hash() ) };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error     => $e,
            uri       => $participation->uri( view => 'edit_form' ),
            form_data => $result->results_hash(),
        );
    }

    $c->redirect_and_detach( $participation->activity()->uri() );
};

del q{}
    => chained '_set_participation'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $self->_check_authz(
        $c,
        'can_edit_account_content',
        { account => $c->account() },
        'You are not authorized to edit this account',
        $c->domain()->application_uri( path => q{} ),
    );

    my $participation = $c->stash()->{participation};

    my $uri = $participation->activity()->uri();

    $participation->delete();

    $c->redirect_and_detach($uri);
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

    my $result = $self->_process_form(
        $c,
        'Report::TopDonors',
        $c->account()->uri( view => 'top_donors' ),
    );

    $c->stash()->{donors}
        = $c->account()->top_donors( $result->results_hash() );

    $c->stash()->{form_vals} = { $result->results_hash() };

    $c->stash()->{template} = '/account/top_donors';
};

get_html 'search'
    => chained '_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    my $name = $c->request()->params()->{search};

    my $search = R2::Search::Contact->new(
        account      => $c->account(),
        restrictions => 'Contact::ByName',
        names        => $name,
    );

    $c->redirect_and_detach( $search->uri( with_host => 1 ) );
};

__PACKAGE__->meta()->make_immutable();

1;
