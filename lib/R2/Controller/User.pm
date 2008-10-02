package R2::Controller::User;

use strict;
use warnings;

use base 'R2::Controller::Base';

use LWPx::ParanoidAgent;
use Net::OpenID::Consumer;
use R2::Schema::User;
use R2::Util qw( string_is_empty );


sub login_form : Local { }

sub authentication : Local : ActionClass('+R2::Action::REST') { }

sub authentication_GET_html
{
    my $self = shift;
    my $c    = shift;

    my $method = $c->request()->param('x-tunneled-method');

    if ( $method && $method eq 'DELETE' )
    {
        $self->authentication_DELETE($c);
        return;
    }
    else
    {
        $c->redirect_and_detach( $c->domain()->application_uri( path => '/user/login_form' ) );
    }
}

sub authentication_POST
{
    my $self = shift;
    my $c    = shift;

    my $uri      = $c->request()->param('openid_uri');
    my $username = $c->request()->param('username');
    my $pw       = $c->request()->param('password');

    my $user;

    if ( ! string_is_empty($uri) )
    {
        $self->_authenticate_openid( $c, $uri );
        return;
    }

    my @errors;

    push @errors, 'You must provide a username or an OpenID URL.'
        if string_is_empty($username);
    push @errors, { field   => 'password',
                    message => 'You must provide a password.' }
        if string_is_empty($pw);

    unless (@errors)
    {
        $user = R2::Schema::User->new( username => $username,
                                       password => $pw,
                                     );

        unless ($user)
        {
            push @errors,
                'The username or password you provided was not valid.';
        }
    }

    if (@errors)
    {
        my $e = R2::Exception::DataValidation->new( errors => \@errors );

        $c->_redirect_with_error
            ( error  => $e,
              uri    => $c->domain()->application_uri( path => '/user/login_form' ),
              params => { username  => $username,
                          return_to => $c->request()->parameters()->{return_to},
                        },
            );
    }

    $self->_login_user( $c, $user );
}

{
    my %OpenIDErrors =
        ( no_identity_server => 'Could not contact an identity server for %s',
          bogus_url          => 'The OpenID URL you provided (%s) is not valid',
          no_head_tag        => 'Got bad data when trying to check your identity server',
          url_fetch_error    => 'Got an error when trying to check your identity server',
        );

    sub _authenticate_openid
    {
        my $self = shift;
        my $c    = shift;
        my $uri  = shift;

        my $csr = $self->_openid_consumer($c);

        my $identity = $csr->claimed_identity($uri);

        unless ($identity)
        {
            my $error = sprintf( $OpenIDErrors{ $csr->errcode() }, $uri );

            $c->_redirect_with_error
                ( error  => $error,
                  uri    => $c->domain()->application_uri( path => '/user/login_form' ),
                  params => { openid_uri => $uri },
                );
        }

        my %query = ( return_to => $c->request()->param('return_to') );
        $query{remember} = 1
            if $c->request()->param('remember');

        my $return_to =
            $c->domain()->application_uri( path  => '/user/openid_authentication',
                                           query => \%query,
                                         );

        my $check_url =
            $identity->check_url
                ( return_to      => $return_to,
                  trust_root     => '/',
                  delayed_return => 1,
                );

        $c->redirect_and_detach($check_url);
    }
}

sub authentication_DELETE
{
    my $self = shift;
    my $c    = shift;

    $c->unset_authen_cookie();

    $c->add_message( 'You have been logged out.' );

    $c->redirect_and_detach( $c->request()->parameters()->{return_to} || '/' );
}

sub openid_authentication : Local
{
    my $self = shift;
    my $c    = shift;

    my $csr = $self->_openid_consumer($c);

    if ( my $setup_url = $csr->user_setup_url() )
    {
        $c->redirect_and_detach($setup_url);
    }
    elsif ( $csr->user_cancel() )
    {
        $c->_redirect_with_error
            ( error  => 'You can still login without OpenID, or make a new account',
              uri    => $c->domain()->application_uri( path => '/user/login_form' ),
            );
    }

    my $identity = $csr->verified_identity();
    unless ($identity)
    {
        $c->_redirect_with_error
            ( error  => 'Something went mysteriously wrong trying to authenticate you with OpenID',
              uri    => $c->domain()->application_uri( path => '/user/login_form' ),
            );
    }

    my $user = R2::Schema::User->new( openid_uri => $identity->url() );

    unless ($user)
    {
        # XXXXXXX?
        $c->_redirect_with_error
            ( error  => 'Now you need to create a Rapport account for your OpenID URL',
              uri    => $c->domain()->application_uri( path => '/user/new_user_form' ),
              params => { openid_uri => $identity->url() },
            );
    }

    $self->_login_user( $c, $user );
}

sub _openid_consumer
{
    my $self = shift;
    my $c    = shift;

    return
        Net::OpenID::Consumer->new
            ( ua              => LWPx::ParanoidAgent->new(),
              args            => $c->request()->params(),
              consumer_secret => sub { $_[0] },
            );
}

sub _login_user
{
    my $self = shift;
    my $c    = shift;
    my $user = shift;

    my %expires = $c->request()->param('remember') ? ( expires => '+1y' ) : ();
    $c->set_authen_cookie( value => { user_id => $user->user_id() },
                           %expires,
                         );

    $c->add_message( 'Welcome to the site, ' . $user->first_name() );

    $c->redirect_and_detach( $c->request()->parameters()->{return_to} || '/' );
}

1;
