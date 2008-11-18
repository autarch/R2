use strict;
use warnings;

use Test::More tests => 17;

use lib 't/lib';
use R2::Test qw( mock_schema mock_dbh );

use R2::Schema::Contact;


my $mock = mock_schema();
my $dbh = mock_dbh();

{
    for my $type ( qw( person organization household ) )
    {
        my $contact =
            R2::Schema::Contact->insert( account_id   => 1,
                                         contact_type => ucfirst $type,
                                       );

        $dbh->{mock_clear_history} = 1;
        $dbh->{mock_add_resultset} =
            [ [ $type . '_id' ],
              [ $contact->contact_id() ],
            ];

        isa_ok( $contact->_build_real_contact(),
                'R2::Schema::' . ucfirst $type,
                '_build_real_contact returns expected type of object' );
    }
}

my $contact =
    R2::Schema::Contact->insert( account_id   => 42,
                                 contact_type => 'Person',
                               );

{
    $mock->recorder()->clear_all();

    my %donation = ( donation_target_id => 1,
                     donation_source_id => 1,
                     payment_type_id    => 1,
                     amount             => 42,
                     donation_date      => '2008-02-24',
                   );
    $contact->add_donation(%donation);

    my ($insert) = $mock->recorder()->actions_for_class('R2::Schema::Donation');
    ok( $insert,
        'add_donation inserted a new donation' );
    is_deeply( $insert->values(),
               { contact_id => $contact->contact_id(),
                 %donation,
               },
               'insert included contact_id' );
}

{
    $mock->recorder()->clear_all();

    my %email = ( email_address => 'dave@example.com',
                );
    $contact->add_email_address(%email);

    my ($insert) = $mock->recorder()->actions_for_class('R2::Schema::EmailAddress');
    ok( $insert,
        'add_email_address inserted a new email address' );
    is_deeply( $insert->values(),
               { contact_id => $contact->contact_id(),
                 %email,
               },
               'insert included contact_id' );
}

{
    $mock->recorder()->clear_all();

    my %website = ( uri => 'http://example.com/',
                  );
    $contact->add_website(%website);

    my ($insert) = $mock->recorder()->actions_for_class('R2::Schema::Website');
    ok( $insert,
        'add_website inserted a new website' );
    is_deeply( $insert->values(),
               { contact_id => $contact->contact_id(),
                 %website,
               },
               'insert included contact_id' );
}

{
    $mock->recorder()->clear_all();

    my %address = ( address_type_id => 1,
                    city            => 'Minneapolis',
                    region          => 'MN',
                    iso_code        => 'us',
                  );
    $contact->add_address(%address);

    my ($insert) = $mock->recorder()->actions_for_class('R2::Schema::Address');
    ok( $insert,
        'add_address inserted a new address' );
    is_deeply( $insert->values(),
               { contact_id => $contact->contact_id(),
                 %address,
               },
               'insert included contact_id' );
}

{
    $mock->recorder()->clear_all();

    my %phone = ( phone_number_type_id => 1,
                  phone_number         => '612-555-1123',
                );
    $contact->add_phone_number(%phone);

    my ($insert) = $mock->recorder()->actions_for_class('R2::Schema::PhoneNumber');
    ok( $insert,
        'add_phone_number inserted a new phone number' );
    is_deeply( $insert->values(),
               { contact_id => $contact->contact_id(),
                 %phone,
               },
               'insert included contact_id' );
}

{
    $mock->recorder()->clear_all();

    my %note = ( contact_note_type_id => 1,
                 note                 => 'blah blah',
                 user_id              => 1,
               );
    $contact->add_note(%note);

    my ($insert) = $mock->recorder()->actions_for_class('R2::Schema::ContactNote');
    ok( $insert,
        'add_note inserted a new note' );
    is_deeply( $insert->values(),
               { contact_id => $contact->contact_id(),
                 %note,
               },
               'insert included contact_id' );
}

{
    my $iterator = $contact->_build_history();

    isa_ok( $iterator, 'Fey::Object::Iterator::Caching' );
}

{
    is( $contact->_base_uri_path(),
        '/account/42/contact/' . $contact->contact_id(),
        '_base_uri_path' );
}
