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
}

{
    my $search = R2::Search::Contact->new(
        account      => $account,
        restrictions => 'Contact::ByName',
        name         => 'John',
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
}

{
    my $search = R2::Search::Contact->new(
        account      => $account,
        restrictions => 'Contact::ByName',
        name         => 'John Cleese',
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
        name         => 'John House',
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

my $tag = R2::Schema::Tag->insert(
    tag        => 'foo',
    account_id => $account->account_id(),
);

{
    my $search = R2::Search::Contact->new(
        account      => $account,
        restrictions => 'Contact::ByTag',
        tag_id       => $tag->tag_id(),
    );

    is(
        $search->contact_count(), 0,
        'Contact search by tag finds 0 contacts'
    );
}

$contacts{CAA}->contact()->add_tags( tags => ['foo'] );
$contacts{'Eric Idle'}->contact()->add_tags( tags => ['foo'] );

{
    my $search = R2::Search::Contact->new(
        account      => $account,
        restrictions => 'Contact::ByTag',
        tag_id       => $tag->tag_id(),
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
    my $search = R2::Search::Person->new(
        account      => $account,
        restrictions => 'Contact::ByName',
        name         => 'John',
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
        restrictions => 'Contact::ByName',
        name         => 'John Cleese',
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
        tag_id       => $tag->tag_id(),
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

done_testing();
