use strict;
use warnings;

use Test::More;

use lib 't/lib';
use R2::Test::RealSchema;

use DateTime;
use Email::Date qw( format_date );
use Email::MessageID;
use Email::MIME;
use File::Slurp qw( read_file );
use R2::EmailProcessor;
use R2::Schema::Account;
use R2::Schema::Contact;
use R2::Schema::User;
use R2::Util qw( string_is_empty );

my $account = R2::Schema::Account->new( name => q{Judean People's Front} );

my $joe = R2::Schema::Person->insert(
    first_name => 'Joe',
    last_name  => 'Smith',
    account_id => $account->account_id(),
    user       => R2::Schema::User->SystemUser(),
);

$joe->contact()->update_or_add_email_addresses(
    {},
    [
        {
            email_address => 'joe@example.com',
            is_preferred  => 1,
        }, {
            email_address => 'shared@example.com',
            is_preferred  => 1,
        },
    ],
    R2::Schema::User->SystemUser(),
);

my $jane = R2::Schema::Person->insert(
    first_name => 'Jane',
    last_name  => 'Smith',
    account_id => $account->account_id(),
    user       => R2::Schema::User->SystemUser(),
);

$jane->contact()->update_or_add_email_addresses(
    {},
    [
        {
            email_address => 'jane@example.com',
            is_preferred  => 1,
        }, {
            email_address => 'shared@example.com',
            is_preferred  => 1,
        },
    ],
    R2::Schema::User->SystemUser(),
);

{
    my $plain = _make_email(
        headers => {
            From    => 'joe@example.com',
            Subject => 'Test 1',
        },
        datetime => DateTime->new( year => 2010, month => 2, day => 24 ),
    );

    R2::EmailProcessor->new(
        account => $account,
        email   => $plain,
    )->process();

    my @emails = $joe->emails()->all();
    is(
        scalar @emails, 1,
        'joe contact has one associated email'
    );

    is(
        $emails[0]->from_contact()->contact_id(),
        $joe->contact_id(),
        'email is identified as being from joe'
    );

    is(
        $emails[0]->subject, 'Test 1',
        'email has correct subject'
    );

    is(
        $emails[0]->email_datetime()->set_time_zone('UTC'),
        DateTime->new( year => 2010, month => 2, day => 24 ),
        'email has the correct datetime'
    );

    my $mime = $emails[0]->email();
    ok(
        !string_is_empty( scalar $mime->header('Message-ID') ),
        'stored message still has a Message-ID header'
    );
}

_delete_all_email();

{
    my @addresses = map { Email::Address->new( @{$_} ) } (
        [ 'A name',     'irrelevant@example.com', '(something)' ],
        [ 'Joe Schmoe', 'joe@example.com' ],
    );

    my $plain = _make_email(
        headers => {
            From    => 'doesnotmatter@example.com',
            CC      => ( join q{ }, @addresses ),
            Subject => 'Test 2',
        },
    );

    R2::EmailProcessor->new(
        account => $account,
        email   => $plain,
    )->process();

    my @emails = $joe->emails()->all();
    is(
        scalar @emails, 1,
        'joe contact has one associated email'
    );

    is(
        $emails[0]->from_contact(),
        undef,
        'email is not from any contact'
    );
}

_delete_all_email();

{
    my $plain = _make_email(
        headers => {
            From    => 'doesnotmatter@example.com',
            To      => 'jane@example.com',
            CC      => 'joe@example.com',
            Subject => 'Test 3',
        },
    );

    R2::EmailProcessor->new(
        account => $account,
        email   => $plain,
    )->process();

    is(
        $joe->email_count(),
        1,
        'joe contact has one associated email'
    );

    is(
        $jane->email_count(),
        1,
        'jane contact has one associated email'
    );
}

_delete_all_email();

{
    my $plain = _make_email(
        headers => {
            From    => 'doesnotmatter@example.com',
            To      => 'shared@example.com',
            Subject => 'Test 4',
        },
    );

    R2::EmailProcessor->new(
        account => $account,
        email   => $plain,
    )->process();

    is(
        $joe->email_count(),
        1,
        'joe contact has one associated email - shared email address'
    );

    is(
        $jane->email_count(),
        1,
        'jane contact has one associated email - shared email address'
    );
}

_delete_all_email();

{
    my $plain = _make_email(
        headers => {
            From    => 'doesnotmatter@example.com',
            To      => 'shared@example.com',
            Subject => 'Test 4',
        },
    );

    R2::EmailProcessor->new(
        account => $account,
        email   => $plain,
    )->process();

    is(
        $joe->email_count(),
        1,
        'joe contact has one associated email - shared email address'
    );

    is(
        $jane->email_count(),
        1,
        'jane contact has one associated email - shared email address'
    );
}

_delete_all_email();

{
    my $attachments = _make_email(
        headers => {
            From    => 'doesnotmatter@example.com',
            To      => 'joe@example.com',
            Subject => 'Test 5',
        },
        attachments => [
            'a' x 500,
            'a' x 50_000_000,
        ],
    );

    R2::EmailProcessor->new(
        account => $account,
        email   => $attachments,
    )->process();

    my @emails = $joe->emails()->all();
    is(
        scalar @emails, 1,
        'joe contact has one associated email'
    );

    my $mime = $emails[0]->email();

    is(
        scalar $mime->parts(),
        2,
        '50MB part was stripped from message before storing it'
    );
}

done_testing();

sub _make_email {
    my %p = @_;

    my %bodies = _email_bodies(%p);

    my @bodies;

    if ( $bodies{text_body} ) {
        push @bodies,
            Email::MIME->create(
            attributes => {
                content_type => 'text/plain',
                charset      => 'utf-8',
                encoding     => 'quoted-printable',
            },
            body => $bodies{text_body},
            );
    }

    if ( $bodies{html_body} ) {
        push @bodies,
            Email::MIME->create(
            attributes => {
                content_type => 'text/html',
                charset      => 'utf-8',
                encoding     => 'quoted-printable',
            },
            body => $bodies{html_body},
            );
    }

    my $body;
    if ( @bodies == 2 ) {
        $body = Email::MIME->create(
            attributes => { content_type => 'multipart/alternative' },
            parts      => \@bodies,
        );
    }
    else {
        $body = $bodies[0];
    }

    my @parts = $body;
    push @parts, map { _email_attachment($_) } @{ $p{attachments} };

    return Email::MIME->create(
        header => _email_headers(%p),
        parts  => \@parts,
    );
}

sub _email_headers {
    my %p = @_;

    my $headers = $p{headers};

    if ( my $dt = $p{datetime} ) {
        $headers->{Date} = format_date( $dt->epoch() );
    }
    else {
        $headers->{Date} = format_date();
    }

    $headers->{'Message-ID'} = Email::MessageID->new()->in_brackets();

    return [ %{$headers} ];
}

sub _email_bodies {
    my %p = @_;

    my %bodies = map { $_ => $p{$_} }
        grep { !string_is_empty( $p{$_} ) } qw( html_body text_body );

    return %bodies if keys %bodies;

    return text_body => <<'EOF';
This is a test body

Nothing here
EOF
}

sub _email_attachment {
    my $attachment = shift;

    if ( ref $attachment ) {
        return Email::MIME->create(
            attributes => {
                content_type => $attachment->{content_type},
                encoding     => $attachment->{encoding} // 'base64',
            },
            body => $attachment->{body},
        );
    }
    else {
        return Email::MIME->create(
            attributes => {
                content_type => 'application/unknown',
                encoding     => 'base64',
            },
            body => $attachment,
        );
    }
}

sub _delete_all_email {
    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    $dbh->do( q{DELETE FROM "Email"} );
}
