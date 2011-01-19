package R2::SeedData;

use strict;
use warnings;

our $VERBOSE;

use File::HomeDir;
use Path::Class;
use Sys::Hostname qw( hostname );

sub seed_data {
    my %p = @_;

    local $VERBOSE = $p{verbose};

    require R2::Schema::Role;

    R2::Schema::Role->EnsureRequiredRolesExist();

    require R2::Schema::ContactHistoryType;

    R2::Schema::ContactHistoryType->EnsureRequiredContactHistoryTypesExist();

    require R2::Schema::MessagingProviderType;

    R2::Schema::MessagingProviderType->EnsureRequiredMessageProviderTypesExist();

    require R2::Schema::TimeZone;

    R2::Schema::TimeZone->EnsureRequiredTimeZonesExist();

    require R2::Schema::HTMLWidget;

    R2::Schema::HTMLWidget->EnsureRequiredHTMLWidgetsExist();

    my $domain = make_domain();
    make_accounts($domain);
}

sub make_domain {
    require R2::Schema::Domain;

    my $domain = R2::Schema::Domain->DefaultDomain();

    my $hostname = $domain->web_hostname();

    if ($VERBOSE) {
        print <<"EOF";

  Made a new domain: $hostname

EOF
    }

    return $domain;
}

sub make_accounts {
    my $domain = shift;

    require R2::Schema::User;
    require R2::Schema::Account;

    for my $names (
        [ q{People's Front of Judea}, q{John Cleese} ],
        [ q{Judean People's Front},   q{Eric Idle} ],
        ) {
        make_account( $domain, @{$names} );
    }
}

sub make_account {
    my $domain       = shift;
    my $account_name = shift;
    my $user_name    = shift;

    my $account = R2::Schema::Account->insert(
        name      => $account_name,
        domain_id => $domain->domain_id(),
    );

    my ( $first_name, $last_name ) = split / /, $user_name;
    ( my $email = lc $user_name ) =~ s/ /./g;
    $email .= '@example.com';

    my $password = 'password';

    my $user = R2::Schema::User->insert(
        password => $password,
        is_system_admin =>
            ( R2::Schema::User->Count() ? 0 : 1 ),
        email_address => $email,
        first_name    => $first_name,
        last_name     => $last_name,
        gender        => 'male',
        account_id    => $account->account_id(),
        role_id       => R2::Schema::Role->Admin()->role_id(),
        user          => R2::Schema::User->SystemUser(),
    );

    if ($VERBOSE) {
        print <<"EOF";

  Created a new account: $account_name

  Admin is $user_name

    email:    $email
    password: $password

EOF
    }
}

1;
