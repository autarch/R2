use strict;
use warnings;

use Test::More;

use lib 't/lib';
use R2::Test::RealSchema;

use R2::Schema::Account;
use R2::Schema::Contact;
use R2::Schema::User;

my $account1 = R2::Schema::Account->new( name => q{Judean People's Front} );
my $account2 = R2::Schema::Account->new( name => q{People's Front of Judea} );

{
    for my $num ( 1 .. 4 ) {
        R2::Schema::CustomFieldGroup->insert(
            name              => 'Group ' . $num,
            applies_to_person => 1,
            account_id        => $account1->account_id(),
        );
    }

    my @groups = $account1->custom_field_groups()->all();

    is_deeply(
        [ map { $_->display_order() } @groups ],
        [ 1 .. 4 ],
        'groups are inserted in display order from 1-4'
    );

    $groups[1]->delete();

    @groups = $account1->custom_field_groups()->all();

    is_deeply(
        [ map { $_->display_order() } @groups ],
        [ 1 .. 3 ],
        'deleting a group reorders remaining groups'
    );

    is_deeply(
        [ map { $_->name() } @groups ],
        [ 'Group 1', 'Group 3', 'Group 4' ],
        'reordered groups have the expected names'
    );
}

done_testing();
