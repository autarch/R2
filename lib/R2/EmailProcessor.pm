package R2::EmailProcessor;

use namespace::autoclean;

use Moose;
use MooseX::ClassAttribute;

use DateTime;
use DateTime::Format::Mail;
use DateTime::TimeZone;
use Email::Address;
use Email::Date;
use Email::MIME;
use Email::MIME::Attachment::Stripper;
use Fey::Placeholder;
use List::AllUtils qw( first sum uniq );
use MooseX::Params::Validate qw( validated_list );
use Number::Format qw( format_bytes );
use R2::Config;
use R2::Schema;
use R2::Schema::ContactEmail;
use R2::Schema::Email;
use R2::Types qw( ArrayRef DatabaseId HashRef Maybe NonEmptyStr );
use R2::Util qw( string_is_empty );

has account => (
    is       => 'ro',
    isa      => 'R2::Schema::Account',
    required => 1,
);

has email => (
    is       => 'rw',
    writer   => '_set_email',
    isa      => 'Email::MIME',
    required => 1,
);

has _subject => (
    is      => 'ro',
    isa     => NonEmptyStr,
    lazy    => 1,
    builder => '_build_subject',
);

has _email_datetime => (
    is      => 'ro',
    isa     => 'DateTime',
    lazy    => 1,
    builder => '_build_email_datetime',
);

has _text_body_part => (
    is      => 'ro',
    isa     => Maybe ['Email::MIME'],
    lazy    => 1,
    builder => '_build_text_body_part',
);

has _html_body_part => (
    is      => 'ro',
    isa     => Maybe ['Email::MIME'],
    lazy    => 1,
    builder => '_build_html_body_part',
);

has _sender_params => (
    is      => 'ro',
    isa     => HashRef [DatabaseId],
    lazy    => 1,
    builder => '_build_sender_params',
);

has _participant_email_addresses => (
    is      => 'ro',
    isa     => ArrayRef[NonEmptyStr],
    lazy    => 1,
    builder => '_build_participant_email_addresses',
);

class_has _SenderSelect => (
    is      => 'ro',
    isa     => 'Fey::SQL::Select',
    builder => '_BuildSenderSelect',
);

class_has _ParticipantSelect => (
    is      => 'ro',
    isa     => 'Fey::SQL::Select',
    builder => '_BuildParticipantSelect',
);

sub process {
    my $self = shift;

    my $email
        = Email::MIME::Attachment::Stripper->new( $self->email() )->message();

    $self->_insert_email();
}

sub _insert_email {
    my $self = shift;

    my %p = (
        %{ $self->_sender_params() },
        subject        => $self->_subject(),
        raw_content    => $self->email()->as_string(),
        email_datetime => $self->_email_datetime,
    );

    my $contact_ids = $self->_contacts_in_email();

    my ( $donation, $contact ) = $self->_donation_data();

    my $create_contact = $contact && !$contact->{contact_id};

    R2::Schema->RunInTransaction(
        sub {
            if ($create_contact) {
                my $class = delete $contact->{class};

                my $new_contact = $class->new();

                push @{$contact_ids}, $new_contact->contact_id();
            }

            if ($donation) {
                my $new_donation
                    = R2::Schema::Donation->insert( %{$donation} );
                $p{donation_id} = $new_donation->donation_id();
            }

            my $email = R2::Schema::Email->insert(%p);

            # If there are no contacts _or_ the only contact for the email is
            # the sending user, then we need to figure out who this email
            # should be associated with.
            my $needs_review = !@{$contact_ids}
                || ( @{$contact_ids} == 1
                && $p{from_user_id}
                && $p{from_contact_id} == $contact_ids->[0] );

            for my $contact_id ( @{$contact_ids} ) {
                R2::Schema::ContactEmail->insert(
                    email_id   => $email->email_id(),
                    contact_id => $contact_id,
                );
            }

            if ($needs_review) {

                # insert into review queue?
            }
        }
    );
}

sub _donation_data {
    my $self = shift;

    for my $type (qw( _nfg_custom )) {
        my $method = $type . '_data';

        my ( $donation, $contact ) = $self->$method;

        return ( $donation, $contact ) if keys %{$donation};
    }
}

# Network for Good Custom DonateNow
sub _nfg_custom_data {
    my $self = shift;

    return unless $self->_subject() =~ /Online donation via Network for Good/;

    my $text = $self->_text_body_part()
        or return;

    my $content = $text->body();

    $content =~ s/\r//g;

    my %donation;

    $donation{donation_date} = $self->_email_datetime();

    ( $donation{amount} ) = $content =~ m{Donation Amount: \$([\d\.]+)};
    $donation{is_recurring} = $content =~ m{Frequency: } ? 1 : 0;
    ( $donation{gift_item} ) = $content =~ m{Name: (.+)};

    my ($gift_value) = $content =~ m{Market Value: (.+)};
    if ($gift_value) {
        my $quantity = $content =~ m{Quantity: (.+)};
        $donation{value_for_donor} = $gift_value * $quantity;
    }

    $donation{external_id} = $content =~ m{External Id: (.+)};
    ( $donation{dedication} ) = $content =~ m{(In (?:memory|honor) .+|On behalf of .+)};

    $donation{note} = 'Created from an email forwarded to the system.';
    $donation{payment_type_id}      = 'Credit Card';    # XXX
    $donation{donation_source_id}   = 'Online';         # XXX
    $donation{donation_campaign_id} = 'Online';         # XXX

    my %contact = ( class => 'R2::Schema::Person' );
    ( $contact{first_name} )    = $content =~ m{First Name: (.+)};
    ( $contact{last_name} )     = $content =~ m{Last Name: (.+)};
    ( $contact{address_1} )     = $content =~ m{Address 1: (.+)};
    ( $contact{address_2} )     = $content =~ m{Address 2: (.+)};
    ( $contact{city} )          = $content =~ m{City: (.+)};
    ( $contact{state} )         = $content =~ m{State/Province: (.+)};
    ( $contact{postal_code} )   = $content =~ m{Zip/Postal Code: (.+)};
    ( $contact{country} )       = $content =~ m{Country: (.+)};
    ( $contact{phone} )         = $content =~ m{Phone/Ext: (.+)};
    ( $contact{email_address} ) = $content =~ m{Email: (.+)};

    $contact{contact_id}
        = $self->_contact_id_for_email_address( $contact{email_address} );

    return \%donation, \%contact;
}

sub _build_sender_params {
    my $self = shift;

    my $from = $self->email()->header('From');

    return if string_is_empty($from);

    my ($address) = Email::Address->parse($from)
        or return;

    my $select = $self->_SenderSelect();

    my $dbh = R2::Schema->DBIManager()->source_for_sql($select)->dbh();

    my $rows = $dbh->selectall_arrayref(
        $select->sql($dbh),
        { Slice => {} },
        $self->account()->account_id(),
        $address->address(),
        $self->account()->account_id(),
    );

    return {} unless $rows && @{$rows} == 1;

    return $rows->[0]{user_id}
        ? {
        from_user_id    => $rows->[0]{user_id},
        from_contact_id => $rows->[0]{contact_id},
        }
        : { from_contact_id => $rows->[0]{contact_id} };
}

sub _BuildSenderSelect {
    my $schema = R2::Schema->Schema();

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $fake_fk = Fey::FK->new(
        source_columns =>
            [ $schema->table('EmailAddress')->column('contact_id') ],
        target_columns => [ $schema->table('User')->column('person_id') ],
    );

    my $where = R2::Schema->SQLFactoryClass()->new_where();
    $where->where(
        $schema->table('User')->column('account_id'), '=',
        Fey::Placeholder->new()
    );

    #<<<
    $select
        ->select( $schema->table('EmailAddress')->column('contact_id'),
                  $schema->table('User')->column('user_id') )
        ->from  ( $schema->tables('EmailAddress', 'Contact') )
        ->from  ( $schema->table('EmailAddress'),
                  'left',
                  $schema->table('User'),
                  $fake_fk,
                  $where )
        ->where ( $schema->table('EmailAddress')->column('email_address'), '=',
                  Fey::Placeholder->new() )
        ->and   ( $schema->table('Contact')->column('account_id'), '=',
                  Fey::Placeholder->new() );
    #>>>

    return $select;
}

sub _contacts_in_email {
    my $self = shift;

    my $addresses = $self->_participant_email_addresses();
    return [] unless @{$addresses};

    my $schema = R2::Schema->Schema();
    my $select = $self->_ParticipantSelect()->clone();

    $select->and(
        $schema->table('EmailAddress')->column('email_address'), 'IN',
        ( Fey::Placeholder->new() ) x @{$addresses}
    );

    my $dbh = R2::Schema->DBIManager()->source_for_sql($select)->dbh();

    my $rows = $dbh->selectcol_arrayref(
        $select->sql($dbh),
        { Slice => {} },
        $self->account()->account_id(),
        @{$addresses},
    );

    return $rows || [];
}

sub _BuildParticipantSelect {
    my $schema = R2::Schema->Schema();

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    #<<<
    $select
        ->select( $schema->table('EmailAddress')->column('contact_id') )
        ->from  ( $schema->tables( 'EmailAddress', 'Contact' ) )
        ->where ( $schema->table('Contact')->column('account_id'), '=',
                  Fey::Placeholder->new() );
    #>>>

    return $select;
}

sub _build_subject {
    my $self = shift;

    my $subject = $self->email()->header('Subject');
    $subject = '(No Subject)' if string_is_empty($subject);

    return $subject;
}

{
    my $parser = DateTime::Format::Mail->new( loose => 1 );

    sub _build_email_datetime {
        my $self = shift;

        # Stolen from Email::Date
        my $raw_date 
            = $self->email()->header('Date')
            || _find_date_received( $self->email()->header('Received') )
            || $self->email()->header('Resent-Date');

        if ( !string_is_empty($raw_date) ) {
            my $dt = eval { $parser->parse_datetime($raw_date) };

            if ($dt) {
                $dt->set_time_zone('UTC');
                return $dt;
            }
        }

        return DateTime->now( time_zone => 'UTC' );
    }
}

# Stolen from Email::Date
sub _find_date_received {
    return unless defined $_[0] and length $_[0];
    my $date = pop;
    $date =~ s/.+;//;
    $date;
}

sub _build_text_body_part {
    my $self = shift;

    return $self->_first_part_with_type('text/plain');
}

sub _build_html_body_part {
    my $self = shift;

    return $self->_first_part_with_type('text/html');
}

sub _first_part_with_type {
    my $self = shift;
    my $type = shift;

    my $first;

    local $@;
    eval {
        $self->email()->walk_parts(
            sub {
                my $part = shift;

                if ( $part->content_type() =~ /^\Q$type\E(?:;|$)/ ) {
                    $first = $part;
                    die;
                }
            }
        );
    };

    return $first;
}

sub _build_participant_email_addresses {
    my $self = shift;

    return [
        uniq(
            map { $_->address() }
            map { Email::Address->parse($_) }
            map { $self->email()->header($_) } qw( From To CC )
        )
    ];
}

{

    package Email::MIME;

    no warnings 'redefine';

    # The version in Email::MIME resets the subparts after every walk, which
    # breaks the attachment stripping code _and_ is hugely inefficient.
    sub walk_parts {
        my ( $self, $callback ) = @_;

        my $walk;
        $walk = sub {
            my ($part) = @_;
            $callback->($part);

            $walk->($_) for $part->subparts;
        };

        my $rv = $walk->($self);

        undef $walk;

        return $rv;
    }
}

__PACKAGE__->meta()->make_immutable();

1;
