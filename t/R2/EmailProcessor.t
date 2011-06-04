use strict;
use warnings;

use Test::More;

use lib 't/lib';
use R2::Test::RealSchema;

use Courriel::Builder;
use DateTime;
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
    my $plain = build_email(
        from('joe@example.com'),
        subject('Test 1'),
        header(
            Date => DateTime::Format::Mail->format_datetime(
                DateTime->new( year => 2010, month => 2, day => 24 )
            ),
        ),
        plain_body('body'),
    );

    R2::EmailProcessor->new(
        account  => $account,
        courriel => $plain,
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

    my $email = $emails[0]->courriel();
    my @id = $email->headers->get('Message-ID');

    is(
        scalar @id,
        1,
        'email has a Message-ID'
    );

    ok(
        !string_is_empty( $id[0] ),
        'stored message still has a Message-ID header'
    );
}

_delete_all_email();

{
    my @addresses = map { Email::Address->new( @{$_} ) } (
        [ 'A name',     'irrelevant@example.com', '(something)' ],
        [ 'Joe Schmoe', 'joe@example.com' ],
    );

    my $plain = build_email(
        from('doesnotmatter@example.com'),
        cc(@addresses),
        subject('Test 2'),
        plain_body('body'),
    );

    R2::EmailProcessor->new(
        account  => $account,
        courriel => $plain,
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
    my $plain = build_email(
        from('doesnotmatter@example.com'),
        to('jane@example.com'),
        cc('joe@example.com'),
        subject('Test 3'),
        plain_body('body'),
    );

    R2::EmailProcessor->new(
        account  => $account,
        courriel => $plain,
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
    my $plain = build_email(
        from('doesnotmatter@example.com'),
        to('shared@example.com'),
        subject('Test 4'),
        plain_body('body'),
    );

    R2::EmailProcessor->new(
        account  => $account,
        courriel => $plain,
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
    my $attachments = build_email(
        from('doesnotmatter@example.com'),
        to('joe@example.com'),
        subject('Test 5'),
        plain_body('body'),
        attach( content => 'a' x 500 ),
        attach( content => 'a' x50_000 ),
    );

    R2::EmailProcessor->new(
        account  => $account,
        courriel => $attachments,
    )->process();

    my @emails = $joe->emails()->all();
    is(
        scalar @emails, 1,
        'joe contact has one associated email'
    );

    my $email = $emails[0]->courriel();

    is(
        $email->part_count(),
        1,
        'attachments were stripped before storing email'
    );
}

done_testing();

sub _delete_all_email {
    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    $dbh->do(q{DELETE FROM "Email"});
}
