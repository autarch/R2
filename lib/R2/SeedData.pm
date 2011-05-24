package R2::SeedData;

use strict;
use warnings;
use autodie;

our $VERBOSE;

use DateTime;
use File::Slurp qw( read_file write_file );
use List::AllUtils qw( shuffle );
use Path::Class qw( dir file );

my $Today = DateTime->today( time_zone => 'floating' );

sub seed_data {
    shift;
    my %p = @_;

    local $VERBOSE = $p{verbose};

    if ( $p{testing} ) {
        return if _maybe_seed_from_cache( $p{db_name} );
    }

    _seed_required_data();

    my $domain = make_domain();
    make_accounts($domain);

    if ( $p{testing} ) {
        _cache_seed_data( $p{db_name} );
    }

    if ( $p{populate} ) {
        _seed_random_contacts();
    }

    if ( $p{email} ) {
        _seed_random_emails();
    }
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

  Domain for this R2 instance: $hostname

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

    return if R2::Schema::Account->new( name => $account_name );

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
    require Text::Lorem::More;

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

        _seed_supporting_contact_data(
            $account,
            $user,
            $person->contact(),
            $data
        );

        $person_ids{ $person->person_id() } = $person->person_id();
    }

    for ( 1 .. 50 ) {
        if ( $VERBOSE && $_ % 50 == 0 ) {
            print "Seeded $_ households\n";
        }

        my $data = $rand->household();

        my $household = _seed_random_household( $account, $user, $data );

        _seed_supporting_contact_data(
            $account,
            $user,
            $household->contact(),
            $data
        );

        _seed_members(
            $account,
            $user,
            $household,
            \%person_ids,
        );
    }

    for ( 1 .. 50 ) {
        if ( $VERBOSE && $_ % 50 == 0 ) {
            print "Seeded $_ organizations\n";
        }

        my $data = $rand->organization();

        my $organization
            = _seed_random_organization( $account, $user, $data );

        _seed_supporting_contact_data(
            $account,
            $user,
            $organization->contact(),
            $data
        );

        _seed_members(
            $account,
            $user,
            $organization,
            \%person_ids,
        );
    }
}

sub _seed_supporting_contact_data {
    my $account = shift;
    my $user    = shift;
    my $contact = shift;
    my $data    = shift;

    _seed_email_addresses_for_contact( $account, $user, $contact, $data );
    _seed_phones_for_contact( $account, $user, $contact, $data );
    _seed_addresses_for_contact( $account, $user, $contact, $data );
    _seed_tags_for_contact( $account, $user, $contact );
    _seed_donations_for_contact( $account, $user, $contact );
    _seed_notes_for_contact( $account, $user, $contact );
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
        salutation        => $data->{salutation},
        first_name        => $data->{given},
        middle_name       => $data->{middle},
        last_name         => $data->{surname},
        suffix            => $data->{suffix},
        birth_date        => $data->{birth_date},
        allows_email      => ( _percent() <= 20 ? 0 : 1 ),
        allows_mail       => ( _percent() <= 30 ? 0 : 1 ),
        allows_phone      => ( _percent() <= 40 ? 0 : 1 ),
        gender            => $data->{gender},
        creation_datetime => _random_datetime(),
    );

    delete $p{$_} for grep { !defined $p{$_} } keys %p;

    return R2::Schema::Person->insert(
        %p,
        account_id => $account->account_id(),
        user       => $user,
    );
}

sub _seed_random_household {
    my $account = shift;
    my $user    = shift;
    my $data    = shift;

    return R2::Schema::Household->insert(
        name              => $data->{name},
        account_id        => $account->account_id(),
        user              => $user,
        creation_datetime => _random_datetime(),
    );
}

sub _seed_random_organization {
    my $account = shift;
    my $user    = shift;
    my $data    = shift;

    return R2::Schema::Organization->insert(
        name              => $data->{name},
        account_id        => $account->account_id(),
        user              => $user,
        creation_datetime => _random_datetime(),
    );
}

{
    my $TenYearsAgo = $Today->clone()->subtract( years => 10 );

    sub _random_datetime {
        my $since = shift || $TenYearsAgo;

        my $days = $Today->delta_days($since)->in_units('days');

        my $dt = $Today->clone()->subtract( days => int( rand($days) ) );

        $dt->add( hours   => int( rand(24) ) );
        $dt->add( minutes => int( rand(60) ) );
        $dt->add( seconds => int( rand(60) ) );

        return $dt;
    }
}

{
    my @TypeNames = qw( home work );

    sub _seed_email_addresses_for_contact {
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
    my @TypeNames;
    my %TypeIds;

    sub _seed_phones_for_contact {
        my $account = shift;
        my $user    = shift;
        my $contact = shift;
        my $data    = shift;

        unless (%TypeIds) {
            for my $type ( grep { $_->applies_to_person() }
                $account->phone_number_types()->all() ) {

                $TypeIds{ lc $type->name() } = $type->phone_number_type_id();
                push @TypeNames, lc $type->name();
            }
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
                    ( $type eq 'mobile' ? ( _percent() <= 20 ? 0 : 1 ) : 0 ),
                };
        }

        $contact->update_or_add_phone_numbers( {}, \@phones, $user )
            if @phones;
    }
}

{
    my @TypeNames;
    my %TypeIds;

    sub _seed_addresses_for_contact {
        my $account = shift;
        my $user    = shift;
        my $contact = shift;
        my $data    = shift;

        unless (%TypeIds) {
            for my $type ( grep { $_->applies_to_person() }
                $account->address_types()->all() ) {

                $TypeIds{ lc $type->name() } = $type->address_type_id();
                push @TypeNames, lc $type->name();
            }
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

sub _seed_tags_for_contact {
    my $account = shift;
    my $user    = shift;
    my $contact = shift;

    my @tags = _tags($account)
        or return;

    $contact->add_tags( tags => \@tags );
}

sub _tags {
    my $account = shift;

    my $tag_rand = _percent();

    return if $tag_rand < 15;

    my $num
        = $tag_rand <= 40 ? 1
        : $tag_rand <= 60 ? 2
        : $tag_rand <= 70 ? 3
        : $tag_rand <= 80 ? 4
        : $tag_rand <= 90 ? 5
        :                   6;

    my @tags = _make_tags($account);

    my @chosen;
    for ( 1 .. $num ) {
        push @chosen, splice @tags, int( rand(@tags) ), 1;
    }

    return @chosen;
}

{
    open my $fh, '<', '/usr/share/dict/words';

    my @words;
    while (<$fh>) {
        next if /\'/;

        chomp;
        push @words, $_;
    }

    sub _words { @words }

    sub _random_words {
        my $count = shift or return;

        return map { $words[ int( rand @words ) ] } 1..$count;
    }
}

{
    my @Tags;

    sub _make_tags {
        return @Tags if @Tags;

        my $account = shift;

        my @words = _words();

        for ( 1 .. 30 ) {
            my $word = splice @words, int( rand(@words) ), 1;
            push @Tags, $word;

            R2::Schema::Tag->insert(
                account_id => $account->account_id(),
                tag        => $word,
            );
        }

        return @Tags;
    }
}

sub _seed_donations_for_contact {
    my $account = shift;
    my $user    = shift;
    my $contact = shift;

    return if _percent() <= 60;

    if ( _percent() <= 15 ) {
        _seed_recurring_donations( $account, $user, $contact );
    }
    else {
        _seed_random_donations( $account, $user, $contact );
    }
}

sub _seed_recurring_donations {
    my $account = shift;
    my $user    = shift;
    my $contact = shift;

    my $years = _random_years();

    my $start_date;
    my %add;

    my $type_rand = _percent();
    my $frequency;

    if ( $type_rand <= 75 || $years == 1 ) {
        $start_date = $Today->clone()->subtract( days => int( rand(28) ) );
        $start_date->subtract( years => $years );
        %add = ( months => 1 );
        $frequency = 'Monthly';
    }
    elsif ( $type_rand <= 95 ) {
        $start_date = $Today->clone()->subtract( days => int( rand(89) ) );
        $start_date->subtract( years => $years );
        %add = ( months => 3 );
        $frequency = 'Quarterly';
    }
    else {
        $start_date = $Today->clone()->subtract( days => int( rand(365) ) );
        $start_date->subtract( years => $years );
        %add = ( years => 1 );
        $frequency = 'Tearly';
    }

    my $campaign = _random_campaign($account);
    my $source   = _random_source($account);
    my $type     = _random_payment_type($account);

    my $amount = _random_amount();
    while ( $start_date <= $Today ) {
        _seed_donation(
            $account,
            $user,
            $contact,
            campaign             => $campaign,
            source               => $source,
            type                 => $type,
            date                 => $start_date,
            amount               => $amount,
            recurrence_frequency => $frequency,
        );

        $start_date->add(%add);
    }
}

sub _seed_random_donations {
    my $account = shift;
    my $user    = shift;
    my $contact = shift;

    my $years = _random_years();

    my $start_date = $Today->clone()->subtract( days => int( rand(365) ) );
    $start_date->subtract( years => $years );

    while ( $start_date <= $Today ) {
        my %gift = _random_gift($start_date);

        my %p = (
            amount => _random_amount(),
            date   => $start_date,
            gift   => \%gift,
        );

        if ( $gift{gift_item} || _percent() <= 10 ) {
            my $percent = rand(0.5);

            $p{value_for_donor} = $p{amount} * $percent;
        }

        _seed_donation( $account, $user, $contact, %p );

        # XXX - this isn't really right - most donors donate in a more regular
        # pattern than "from 30 and 699 days between donations"
        $start_date->add( days => int( rand(670) ) + 30 );
    }
}

sub _seed_donation {
    my $account = shift;
    my $user    = shift;
    my $contact = shift;
    my %p       = @_;

    $p{campaign} ||= _random_campaign($account);
    $p{source}   ||= _random_source($account);
    $p{type}     ||= _random_payment_type($account);

    my $trans_percent = $p{type}->name() eq 'Credit card' ? 0.029 : 0;

    my %receipt_date;
    my $days_ago = $Today->delta_days( $p{date} )->in_units('days');

    if ( $days_ago <= 8 ) {
        if ( _percent() > ( 80 - ( $days_ago * 10 ) ) ) {
            %receipt_date = ( receipt_date => $Today->clone()
                    ->subtract( days => int( rand($days_ago) ) ) );
        }
    }
    else {
        %receipt_date
            = (
            receipt_date => $p{date}->clone()->add( days => int( rand(8) ) )
            );
    }

    my %gift       = %{ $p{gift}       || {} };
    my %dedication = %{ $p{dedication} || {} };

    $contact->add_donation(
        amount           => $p{amount},
        donation_date    => $p{date},
        transaction_cost => ( $p{amount} * $trans_percent ),
        (
            $p{recurrence_frequency}
            ? ( recurrence_frequency => $p{recurrence_frequency} )
            : ()
        ),
        %receipt_date,
        donation_campaign_id => $p{campaign}->donation_campaign_id(),
        donation_source_id   => $p{source}->donation_source_id(),
        payment_type_id      => $p{type}->payment_type_id(),
        value_for_donor      => $p{value_for_donor} || 0,
        %gift,
        %dedication,
        user => $user,
    );
}

{
    my @Amounts;
    push @Amounts, (10) x 20;
    push @Amounts, (25) x 15;
    push @Amounts, (50) x 8;
    push @Amounts, (100) x 5;
    push @Amounts, (250) x 3;
    push @Amounts, (500) x 2;
    push @Amounts, 1000;

    sub _random_amount {
        return $Amounts[ int( rand(@Amounts) ) ];
    }
}

sub _random_years {
    my $years_rand = _percent();

    return
          $years_rand <= 15 ? 1
        : $years_rand <= 40 ? 2
        : $years_rand <= 60 ? 3
        : $years_rand <= 80 ? 4
        : $years_rand <= 90 ? 5
        : $years_rand <= 92 ? 6
        : $years_rand <= 94 ? 7
        : $years_rand <= 96 ? 8
        : $years_rand <= 98 ? 9
        :                     10;
}

{
    my @Campaigns;

    sub _random_campaign {
        my $account = shift;

        @Campaigns = $account->donation_campaigns()->all()
            unless @Campaigns;

        return $Campaigns[ int( rand(@Campaigns) ) ];
    }
}

{
    my @Sources;

    sub _random_source {
        my $account = shift;

        @Sources = $account->donation_sources()->all()
            unless @Sources;

        return $Sources[ int( rand(@Sources) ) ];
    }
}

{
    my @Types;

    sub _random_payment_type {
        my $account = shift;

        @Types = $account->payment_types()->all()
            unless @Types;

        return $Types[ int( rand(@Types) ) ];
    }
}

{
    my @Gifts = qw( Book Shirt Mug Calendar );

    sub _random_gift {
        my $date = shift;

        return if _percent() <= 90;

        my %gift = ( gift_item => $Gifts[ int( rand(@Gifts) ) ] );

        my $days_ago = $Today->delta_days($date)->in_units('days');
        if ( $days_ago <= 30 ) {
            if ( _percent() > ( 90 - ( $days_ago * 3 ) ) ) {
                $gift{gift_sent_date} = $Today->clone()
                    ->subtract( days => int( rand($days_ago) ) );
            }
        }
        else {
            $gift{gift_sent_date}
                = $date->clone()->add( days => int( rand(30) ) );
        }

        return %gift;
    }
}

{
    my @Types;

    sub _seed_notes_for_contact {
        my $account = shift;
        my $user    = shift;
        my $contact = shift;

        return if _percent() <= 20;

        unless (@Types) {
            @Types = $account->contact_note_types()->all();
        }

        my $num = ( int( rand(20) ) ) + 1;

        for my $x ( 1 .. $num ) {
            my $type = $Types[ int( rand(@Types) ) ];

            $contact->add_note(
                contact_note_type_id => $type->contact_note_type_id(),
                note_datetime =>
                    _random_datetime( $contact->creation_datetime() ),
                note    => _random_paragraphs(),
                user_id => $user->user_id(),
            );
        }
    }
}

{
    my $Lorem;
    sub _random_paragraphs {
        my $max_paras = shift // 4;

        require Text::Lorem::More;

        $Lorem ||= Text::Lorem::More->new();

        my $paras = ( int( rand($max_paras) ) ) + 1;

        return $Lorem->paragraphs($paras);
    }
}

{
    my @HouseholdPositions    = qw( Mother Father Son Daughter );
    my @OrganizationPositions = qw( President CEO Trustee Employee );

    sub _seed_members {
        my $account    = shift;
        my $user       = shift;
        my $contact    = shift;
        my $person_ids = shift;

        return
            if $contact->isa('R2::Schema::Organization') && _percent() <= 40;

        my @positions;
        if ( $contact->isa('R2::Schema::Household') ) {
            @positions = shuffle @HouseholdPositions;
        }
        else {
            @positions = shuffle @OrganizationPositions;
        }

        my $num = ( int( rand(4) ) ) + 1;

        for my $i ( 1 .. $num ) {
            my %position
                = _percent() <= 50
                ? ( position => $positions[ $i - 1 ] )
                : ();

            my @ids = keys %{$person_ids};
            my $id  = delete $person_ids->{ $ids[ int( rand(@ids) ) ] };

            $contact->add_member(
                person_id => $id,
                %position,
                user => $user,
            );
        }
    }
}

sub _seed_random_emails {
    require R2::EmailProcessor;
    require DateTime::Format::Mail;
    require Email::MIME;
    require Email::MessageID;

    my $account
        = R2::Schema::Account->new( name => q{People's Front of Judea} );

    my $sql = <<'EOF';
SELECT distinct email_address
  FROM "EmailAddress" JOIN "Contact" USING (contact_id)
 WHERE account_id = ?
EOF

    my $addresses = R2::Schema->DBIManager()->default_source()->dbh()
        ->selectcol_arrayref( $sql, undef, $account->account_id() );

    # $count times 0.8 to 1.2
    my $count = int( scalar @{$addresses} * ( rand(0.4) + 0.8 ) );

    my $x = 1;

    while ( $count > 0 ) {
        my $to_count = _seed_one_email( $account, $addresses );

        $count -= scalar $to_count;

        if ( $VERBOSE && $x % 50 == 0 ) {
            print "Seeded $x emails\n";
        }

        $x++;
    }
}

sub _seed_one_email {
    my $account   = shift;
    my $addresses = shift;

    my @to = _email_recipients($addresses);

    my $from
        = _percent() <= 70
        ? $addresses->[ rand @{$addresses} ]
        : 'not.in.the.database@example.com';

    my $email = _email_mime( \@to, $from );

    R2::EmailProcessor->new(
        account => $account,
        email   => $email,
    )->process();

    return scalar @to;
}

sub _email_recipients {
    my $addresses = shift;

    my $percent = _percent();

    my $recipients
        = $percent <= 50 ? 1
        : $percent <= 70 ? 2
        : $percent <= 80 ? 3
        : $percent <= 85 ? 4
        : $percent <= 90 ? 5
        : $percent <= 95 ? 6
        :                  $percent - 89;

    return map { $addresses->[ rand @{$addresses} ] } 1 .. $recipients;
}

sub _email_mime {
    my $to   = shift;
    my $from = shift;

    my $percent = _percent();

    my $text_body;
    my $html_body;

    my $paras = _random_paragraphs( int( rand 8 ) + 1 );

    if ( $percent <= 80 ) {
        $text_body = $paras;
        $html_body = _html_email_body($paras);
    }
    elsif ( $percent <= 90 ) {
        $text_body = $paras
    }
    else {
        $html_body = _html_email_body($paras);
    }

    my @bodies;

    # XXX - it would be good to vary the body charset
    if ($text_body) {
        push @bodies,
            Email::MIME->create(
            attributes => {
                content_type => 'text/plain',
                charset      => 'utf-8',
                encoding     => 'quoted-printable',
            },
            body => $text_body,
            );
    }

    if ($html_body) {
        push @bodies,
            Email::MIME->create(
            attributes => {
                content_type => 'text/html',
                charset      => 'utf-8',
                encoding     => 'quoted-printable',
            },
            body => $html_body,
            );
    }

    my %headers = (
        From    => $from,
        To      => ( join q{,}, @{$to} ),
        Subject => ( join q{ }, _random_words( int( rand(15) ) + 1 ) ),
        (
            _percent() <= 98
            ? ( 'Message-ID' => Email::MessageID->new()->in_brackets() )
            : ()
        ),
        (
            _percent() <= 98
            ? (
                'Date' => DateTime::Format::Mail->format_datetime(
                    _random_datetime()
                )
                )
            : ()
        ),
    );

    if ( @bodies == 2 ) {
        return Email::MIME->create(
            header     => [%headers],
            attributes => { content_type => 'multipart/alternative' },
            parts      => \@bodies,
        );
    }
    else {
        $bodies[0]->header_set( $_ => $headers{$_} ) for keys %headers;
        return $bodies[0];
    }
}

# XXX - need to add other markup, especially tables, images, inline styles,
# inline JS, etc.
sub _html_email_body {
    my $paras = shift;

    return join "\n\n", map {"<p>\n$_\n</p>"} split /\n+/, $paras;
}

sub _maybe_seed_from_cache {
    my $db_name = shift;

    my $file = _cache_file();

    return
        unless -f $file
            && $file->stat()->mtime()
            >= file( $INC{'R2/SeedData.pm'} )->stat()->mtime();

    require R2::Config;
    require R2::DatabaseManager;

    # Suppresses a "variable used only once" warning from inside Test::Builder
    $R2::SeedData::TODO = $R2::SeedData::TODO;
    Test::More::diag("Seeding from cached data in $file");

    my $psql = R2::DatabaseManager->new( db_name => $db_name )->_psql();

    $psql->run(
        database => R2::Config->instance()->database_name(),
        options  => [ '-q', '-o', '/dev/null', '-f', $file->stringify() ],
    );

    return 1;
}

sub _percent {
    return ( int( rand(100) ) ) + 1;
}

sub _cache_seed_data {
    my $db_name = shift;

    require R2::Config;
    require R2::DatabaseManager;

    my $file = _cache_file();

    $R2::SeedData::TODO = $R2::SeedData::TODO;
    Test::More::diag("Caching seed data to $file");

    my $pg_dump = R2::DatabaseManager->new( db_name => $db_name )->_pg_dump();

    $pg_dump->run(
        database => $db_name,
        options  => [ '-a', '-T', q{"Version"}, '-f', $file->stringify() ],
    );
}

{
    my $Cache;

    sub _cache_file {
        require R2::Config;

        return $Cache if $Cache;

        return $Cache
            = R2::Config->instance()->cache_dir()->file('seed-data.pg');
    }
}

1;
