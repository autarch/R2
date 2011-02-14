use strict;
use warnings;

use Test::Most;

use lib 't/lib';

use R2::Test::RealSchema;

use R2::Search::Contact;
use R2::Schema::Household;
use R2::Schema::Organization;
use R2::Schema::Person;
use R2::Schema::User;

my $account = R2::Schema::Account->new( name => q{People's Front of Judea} );
my $user = R2::Schema::User->SystemUser();

for my $name (
    [ 'Eric',   'Idle' ],
    [ 'Graham', 'Chapman' ],
    [ 'Terry',  'Gilliam' ]
    ) {

    R2::Schema::Person->insert(
        first_name => $name->[0],
        last_name  => $name->[1],
        account_id => $account->account_id(),
        user       => $user,
    );
}

for my $name (qw( CAA MFA )) {
    R2::Schema::Organization->insert(
        name       => $name,
        account_id => $account->account_id(),
        user       => $user,
    );
}

for my $name ( 'The Foos', 'The Bars', 'John House' ) {
    R2::Schema::Household->insert(
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
            'CAA',
            'Graham Chapman',
            'John Cleese',
            'Terry Gilliam',
            'Eric Idle',
            'John House',
            'MFA',
            'The Bars',
            'The Foos',
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
        'search by name finds 2 contacts'
    );

    is_deeply(
        [ map { $_->display_name() } $search->contacts()->all() ],
        [ 'John Cleese', 'John House', ],
        'contacts match search by name, sorted by name'
    );
}

done_testing();
