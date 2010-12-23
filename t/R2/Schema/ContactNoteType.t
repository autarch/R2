use strict;
use warnings;

use Test::More;

use lib 't/lib';

use R2::Test::RealSchema;

use R2::Schema::ContactNoteType;
use R2::Schema::Person;
use R2::Schema::User;

my $account = R2::Schema::Account->new( name => q{Judean People's Front} );

{
    my $type = R2::Schema::ContactNoteType->new(
        description => 'Made a note',
        account_id  => $account->account_id(),
    );

    ok(
        !$type->is_updateable(),
        'system defined note type is not updateable'
    );
    ok(
        !$type->is_deletable(),
        'system defined note type is not deletable'
    );
}

{
    my $contact = R2::Schema::Person->insert(
        account_id => $account->account_id(),
        first_name => 'Jane',
        user       => R2::Schema::User->SystemUser(),
    )->contact();

    my $type = R2::Schema::ContactNoteType->new(
        description => 'Called this contact',
        account_id  => $account->account_id(),
    );

    ok(
        $type->is_updateable(),
        'user defined note type is updateable'
    );
    ok(
        $type->is_deletable(),
        'user defined note type is deletable when it has no associated notes'
    );

    $contact->add_note(
        note                 => 'Had a chat',
        contact_note_type_id => $type->contact_note_type_id(),
        user_id              => R2::Schema::User->SystemUser()->user_id(),
    );

    ok(
        $type->is_updateable(),
        'user defined note type is updateable even when it has associated notes'
    );
    ok(
        !$type->is_deletable(),
        'user defined note type is not deletable when it has associated notes'
    );
}

done_testing();
