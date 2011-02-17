use strict;
use warnings;

use Test::Most;

use lib 't/lib';

use R2::Test::RealSchema;

use R2::Search::Contact;
use R2::Search::Person;
use R2::Schema::Household;
use R2::Schema::Organization;
use R2::Schema::Person;
use R2::Schema::User;

my $account = R2::Schema::Account->new( name => q{People's Front of Judea} );
my $user = R2::Schema::User->SystemUser();

my %contacts;

for my $name (
    [ 'Eric',   'Idle' ],
    [ 'Graham', 'Chapman' ],
    [ 'Terry',  'Gilliam' ]
    ) {

    $contacts{"$name->[0] $name->[1]"} = R2::Schema::Person->insert(
        first_name => $name->[0],
        last_name  => $name->[1],
        account_id => $account->account_id(),
        user       => $user,
    );
}

for my $name (qw( CAA MFA )) {
    $contacts{$name} = R2::Schema::Organization->insert(
        name       => $name,
        account_id => $account->account_id(),
        user       => $user,
    );
}

for my $name ( 'The Foos', 'The Bars', 'John House' ) {
    $contacts{$name} = R2::Schema::Household->insert(
        name       => $name,
        account_id => $account->account_id(),
        user       => $user,
    );
}

{
    my $search = R2::Search::Contact->new( account => $account );

    is(
        $search->contact_count(), 9,
        'search finds 8 contacts'
    );

    is_deeply(
        [ map { $_->display_name() } $search->contacts()->all() ],
        [
            'The Bars',
            'CAA',
            'Graham Chapman',
            'John Cleese',
            'The Foos',
            'Terry Gilliam',
            'Eric Idle',
            'John House',
            'MFA',
        ],
        'contacts returned sorted by name'
    );

    is(
        $search->title(), 'All Contacts',
        'title for all contacts search '
    );
}

{
    my $search = R2::Search::Contact->new(
        account      => $account,
        restrictions => 'Contact::ByName',
        names        => 'John',
    );

    is(
        $search->contact_count(), 2,
        'Contact search by name finds 2 contacts'
    );

    is_deeply(
        [ map { $_->display_name() } $search->contacts()->all() ],
        [ 'John Cleese', 'John House', ],
        'contacts match search by name, sorted by name'
    );

    is(
        $search->title(), 'Contact Search',
        'title for filtered contact search '
    );
}

{
    my $search = R2::Search::Contact->new(
        account      => $account,
        restrictions => 'Contact::ByName',
        names        => [ 'John', 'Eric' ],
    );

    is(
        $search->contact_count(), 3,
        'Contact search by name finds 3 contacts for two names'
    );

    is_deeply(
        [ map { $_->display_name() } $search->contacts()->all() ],
        [ 'John Cleese', 'Eric Idle', 'John House', ],
        'contacts match search by name, sorted by name'
    );
}

{
    my $search = R2::Search::Contact->new(
        account      => $account,
        restrictions => 'Contact::ByName',
        names        => 'John Cleese',
    );

    is(
        $search->contact_count(), 1,
        'Contact search by name finds 1 contact'
    );

    is_deeply(
        [ map { $_->display_name() } $search->contacts()->all() ],
        [ 'John Cleese', ],
        'contacts match search by name, sorted by name'
    );
}

{
    my $search = R2::Search::Contact->new(
        account      => $account,
        restrictions => 'Contact::ByName',
        names        => 'John House',
    );

    is(
        $search->contact_count(), 1,
        'Contact search by name finds 1 contact'
    );

    is_deeply(
        [ map { $_->display_name() } $search->contacts()->all() ],
        [ 'John House', ],
        'contacts match search by name, sorted by name'
    );
}

my $foo = R2::Schema::Tag->insert(
    tag        => 'foo',
    account_id => $account->account_id(),
);

my $bar = R2::Schema::Tag->insert(
    tag        => 'bar',
    account_id => $account->account_id(),
);

{
    my $search = R2::Search::Contact->new(
        account      => $account,
        restrictions => 'Contact::ByTag',
        tag_ids      => $foo->tag_id(),
    );

    is(
        $search->contact_count(), 0,
        'Contact search by tag finds 0 contacts'
    );
}

$contacts{CAA}->contact()->add_tags( tags => ['foo'] );
$contacts{'Eric Idle'}->contact()->add_tags( tags => ['foo'] );
$contacts{'MFA'}->contact()->add_tags( tags => ['bar'] );
$contacts{'Graham Chapman'}->contact()->add_tags( tags => ['bar'] );

{
    my $search = R2::Search::Contact->new(
        account      => $account,
        restrictions => 'Contact::ByTag',
        tag_ids      => $foo->tag_id(),
    );

    is(
        $search->contact_count(), 2,
        'Contact search by tag finds 2 contacts'
    );


    is_deeply(
        [ map { $_->display_name() } $search->contacts()->all() ],
        [ 'CAA', 'Eric Idle' ],
        'contacts match search by tag, sorted by name'
    );
}

{
    my $search = R2::Search::Contact->new(
        account      => $account,
        restrictions => 'Contact::ByTag',
        tag_ids      => [ $foo->tag_id(), $bar->tag_id() ],
    );

    is(
        $search->contact_count(), 4,
        'Contact search by tag finds 4 contacts for two tags'
    );

    is_deeply(
        [ map { $_->display_name() } $search->contacts()->all() ],
        [ 'CAA', 'Graham Chapman', 'Eric Idle', 'MFA' ],
        'contacts match search by tag, sorted by name'
    );
}

{
    my $search = R2::Search::Person->new(
        account      => $account,
        restrictions => 'Contact::ByName',
        names        => 'John',
    );

    is(
        $search->person_count(), 1,
        'Person search by name finds 1 contact'
    );

    is_deeply(
        [ map { $_->display_name() } $search->people()->all() ],
        [ 'John Cleese', ],
        'people match search by name, sorted by name'
    );

    is(
        $search->title(), 'People Search',
        'title for filtered person search '
    );
}

{
    my $search = R2::Search::Person->new(
        account      => $account,
        restrictions => 'Contact::ByName',
        names        => [ 'John', 'Nonexistent' ],
    );

    is(
        $search->person_count(), 1,
        'Person search by name finds 1 contact for two names (one does not exist)'
    );

    is_deeply(
        [ map { $_->display_name() } $search->people()->all() ],
        [ 'John Cleese', ],
        'people match search by name, sorted by name'
    );
}

{
    my $search = R2::Search::Person->new(
        account      => $account,
        restrictions => 'Contact::ByName',
        names        => [ 'John', 'Eric' ],
    );

    is(
        $search->person_count(), 2,
        'Person search by name finds 2 contacts for two names'
    );

    is_deeply(
        [ map { $_->display_name() } $search->people()->all() ],
        [ 'John Cleese', 'Eric Idle' ],
        'people match search by name, sorted by name'
    );
}

{
    my $search = R2::Search::Person->new(
        account      => $account,
        restrictions => 'Contact::ByName',
        names        => 'John Cleese',
    );

    is(
        $search->person_count(), 1,
        'Person search by name finds 1 contact'
    );

    is_deeply(
        [ map { $_->display_name() } $search->people()->all() ],
        [ 'John Cleese', ],
        'people match search by name, sorted by name'
    );
}

{
    my $search = R2::Search::Person->new(
        account      => $account,
        restrictions => 'Contact::ByTag',
        tag_ids      => $foo->tag_id(),
    );

    is(
        $search->person_count(), 1,
        'Person search by tag finds 1 contact'
    );


    is_deeply(
        [ map { $_->display_name() } $search->people()->all() ],
        [ 'Eric Idle' ],
        'people match search by tag, sorted by name'
    );
}

{
    my $search = R2::Search::Person->new(
        account      => $account,
        restrictions => 'Contact::ByTag',
        tag_ids      => [ $foo->tag_id(), $bar->tag_id() ],
    );

    is(
        $search->person_count(), 2,
        'Person search by tag finds 2 contacts for two tags'
    );

    is_deeply(
        [ map { $_->display_name() } $search->people()->all() ],
        [ 'Graham Chapman', 'Eric Idle' ],
        'people match search by tag, sorted by name'
    );
}

{
    my $search = R2::Search::Person->new( account => $account );

    is(
        $search->title(), 'All People',
        'title for all people search '
    );
}

done_testing();
