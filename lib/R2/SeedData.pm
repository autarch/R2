package R2::SeedData;

use strict;
use warnings;

our $VERBOSE;

use File::HomeDir;
use List::AllUtils qw( shuffle );
use Path::Class;
use Sys::Hostname qw( hostname );

sub seed_data {
    shift;
    my %p = @_;

    local $VERBOSE = $p{verbose};

    _seed_required_data();

    my $domain = make_domain();
    make_accounts($domain);
}

sub seed_lots_of_data {
    shift;
    my %p = @_;

    local $VERBOSE = $p{verbose};

    _seed_required_data();

    my $domain = make_domain();
    make_accounts($domain);

    _seed_random_contacts();
}

sub _seed_required_data {
    require R2::Schema::Role;

    R2::Schema::Role->EnsureRequiredRolesExist();

    require R2::Schema::ContactHistoryType;

    R2::Schema::ContactHistoryType->EnsureRequiredContactHistoryTypesExist();

    require R2::Schema::MessagingProviderType;

    R2::Schema::MessagingProviderType
        ->EnsureRequiredMessageProviderTypesExist();

    require R2::Schema::TimeZone;

    R2::Schema::TimeZone->EnsureRequiredTimeZonesExist();

    require R2::Schema::HTMLWidget;

    R2::Schema::HTMLWidget->EnsureRequiredHTMLWidgetsExist();
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
        username => $email,
        password => $password,
        is_system_admin =>
            ( R2::Schema::User->Count() ? 0 : 1 ),
        first_name => $first_name,
        last_name  => $last_name,
        gender     => 'male',
        account_id => $account->account_id(),
        role_id    => R2::Schema::Role->Admin()->role_id(),
        user       => R2::Schema::User->SystemUser(),
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

sub _seed_random_contacts {
    require Data::Random::Contact;

    my $account
        = R2::Schema::Account->new( name => q{People's Front of Judea} );

    my $rand = Data::Random::Contact->new();

    my $user = R2::Schema::User->SystemUser();

    my %person_ids;
    for ( 1 .. 4000 ) {
        if ( $VERBOSE && $_ % 50 == 0 ) {
            print "Seeded $_ people\n";
        }

        my $data = $rand->person();

        my $person = _seed_random_person( $account, $user, $data );
        my $contact = $person->contact();

        _seed_emails_for_contact( $account, $user, $contact, $data );
        _seed_phones_for_contact( $account, $user, $contact, $data );
        _seed_addresses_for_contact( $account, $user, $contact, $data );

        $person_ids{ $person->person_id() } = 1;
    }
}

sub _seed_random_person {
    my $account = shift;
    my $user    = shift;
    my $data    = shift;

    my $name_rand = _percent();
    if ( $name_rand <= 5 ) {
        delete $data->{given};
    }
    elsif ( $name_rand <= 10 ) {
        delete $data->{surname};
    }

    if ( _percent() <= 50 ) {
        delete $data->{salutation};
    }

    if ( _percent() <= 98 ) {
        delete $data->{suffix};
    }

    if ( _percent() <= 50 ) {
        delete $data->{birth_date};
    }

    if ( _percent() <= 10 ) {
        delete $data->{gender};
    }

    my %p = (
        salutation   => $data->{salutation},
        first_name   => $data->{given},
        middle_name  => $data->{middle},
        last_name    => $data->{surname},
        suffix       => $data->{suffix},
        birth_date   => $data->{birth_date},
        allows_email => ( _percent() <= 20 ? 0 : 1 ),
        allows_mail  => ( _percent() <= 30 ? 0 : 1 ),
        allows_phone => ( _percent() <= 40 ? 0 : 1 ),
        gender       => $data->{gender},
    );

    delete $p{$_} for grep { !defined $p{$_} } keys %p;

    return R2::Schema::Person->insert(
        %p,
        account_id => $account->account_id(),
        user       => $user,
    );
}

{
    my @TypeNames = qw( home work );

    sub _seed_emails_for_contact {
        my $account = shift;
        my $user    = shift;
        my $contact = shift;
        my $data    = shift;

        my @emails;

        my $threshold = 30;
        for my $type ( shuffle @TypeNames ) {
            next unless $data->{email}{$type};

            next if _percent() <= $threshold;

            $threshold += 30;

            push @emails, {
                email_address => $data->{email}{$type},
                };
        }

        $contact->update_or_add_email_addresses( {}, \@emails, $user )
            if @emails;
    }
}

{
    my @TypeNames = qw( cell home work office );
    my %TypeIds;

    sub _seed_phones_for_contact {
        my $account = shift;
        my $user    = shift;
        my $contact = shift;
        my $data    = shift;

        unless (%TypeIds) {
            $TypeIds{ lc $_->name() } = $_->phone_number_type_id()
                for $account->phone_number_types()->all();
        }

        my @phones;

        my $threshold = 30;
        for my $type ( shuffle @TypeNames ) {
            next unless $data->{phone}{$type};

            next if _percent() <= $threshold;

            $threshold += 30;

            push @phones, {
                phone_number_type_id => $TypeIds{$type},
                phone_number         => $data->{phone}{$type},
                allows_sms =>
                    ( $type eq 'cell' ? ( _percent() <= 20 ? 0 : 1 ) : 0 ),
                };
        }

        $contact->update_or_add_phone_numbers( {}, \@phones, $user )
            if @phones;
    }
}

{
    my @TypeNames = qw( home work headquarters branch );
    my %TypeIds;

    sub _seed_addresses_for_contact {
        my $account = shift;
        my $user    = shift;
        my $contact = shift;
        my $data    = shift;

        unless (%TypeIds) {
            $TypeIds{ lc $_->name() } = $_->address_type_id()
                for $account->address_types()->all();
        }

        my @addresses;

        my $threshold = 30;
        for my $type ( shuffle @TypeNames ) {
            next unless $data->{address}{$type};

            next if _percent() <= $threshold;

            $threshold += 30;

            delete $data->{address}{$type}{region_abbr};

            my %address = %{ $data->{address}{$type} };
            delete $address{$_}
                for grep { !defined $address{$_} } keys %address;

            push @addresses, {
                address_type_id => $TypeIds{$type},
                %address,
                };
        }

        $contact->update_or_add_addresses( {}, \@addresses, $user )
            if @addresses;
    }
}

sub _percent {
    return ( int( rand(100) ) ) + 1;
}

1;
