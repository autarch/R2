package R2::Schema::Donation;

use strict;
use warnings;
use namespace::autoclean;

use DateTime::Format::Natural;
use List::AllUtils qw( first );
use Number::Format qw( format_number );
use R2::Schema::DonationCampaign;
use R2::Schema::DonationSource;
use R2::Schema;
use R2::Types qw( Str );
use R2::Util qw( string_is_empty );
use Scalar::Util qw( looks_like_number );

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator' =>
    { steps => [qw( _validate_amount _valid_donation_date _valid_receipt_date )] };
with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Donation') );

    has_one source => ( table => $schema->table('DonationSource') );

    has_one campaign => ( table => $schema->table('DonationCampaign') );

    has_one( $schema->table('PaymentType') );

    my @fks = $schema->foreign_keys_between_tables(
        $schema->tables( 'Donation', 'Contact' ) );

    has_one contact => (
        table => $schema->table('Contact'),
        fk    => (
            first {
                $_->has_column(
                    $schema->table('Donation')->column('contact_id') );
            }
            @fks
        ),
    );

    has_one dedicated_to_contact => (
        table => $schema->table('Contact'),
        fk    => (
            first {
                $_->has_column( $schema->table('Donation')
                        ->column('dedicated_to_contact_id') );
            }
            @fks
        ),
        undef => 1,
    );

    has formatted_amount => (
        is       => 'ro',
        isa      => Str,
        init_arg => undef,
        lazy     => 1,
        builder  => '_build_formatted_amount',
    );
}

with 'R2::Role::Schema::HistoryRecorder';

sub _validate_amount {
    my $self = shift;
    my $p    = shift;

    # remove any currency symbols and such
    $p->{amount} =~ s/^[^\d\-](\d)/$1/;
    $p->{amount} =~ s/,//g;

    # will be caught later
    return if string_is_empty( $p->{amount} );

    my $msg;

    if ( !looks_like_number( $p->{amount} ) ) {
        $msg
            = "The amount you specified ($p->{amount}) does not seem to be a number.";
    }
    elsif ( $p->{amount} <= 0 ) {
        $msg = 'The amount for a donation cannot be negative.';
    }
    elsif ( sprintf( '%.2f', $p->{amount} ) != $p->{amount} ) {
        $msg
            = 'You cannot have more than two digits to the right of the decimal point.';
    }

    return unless $msg;

    return {
        message => $msg,
        field   => 'amount',
    };
}

sub _valid_donation_date {
    my $self = shift;

    return $self->_valid_date( @_, 'donation_date' );
}

sub _valid_receipt_date {
    my $self = shift;

    return $self->_valid_date( @_, 'receipt_date' );
}

sub _valid_gift_sent_date {
    my $self = shift;

    return $self->_valid_date( @_, 'gift_sent_date' );
}

sub _valid_date {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;
    my $field     = shift;

    return if string_is_empty( $p->{$field} );

    return if blessed $p->{$field};

    my $parser = DateTime::Format::Natural->new(
        time_zone => 'floating',
    );

    my $dt = $parser->parse_datetime( $p->{$field} );

    return {
        field   => '$field',
        message => 'This does not seem to be a valid date.',
        }
        unless $dt && !$parser->error();

    $p->{$field} = $dt;

    return;
}

sub _build_formatted_amount {
    my $self = shift;

    return format_number( $self->amount(), 2, 'trailing zeroes' );
}

sub _base_uri_path {
    my $self = shift;

    return
          $self->contact()->_base_uri_path()
        . '/donation/'
        . $self->donation_id();
}

sub summary {
    my $self = shift;

    return $self->formatted_amount() . ' from '
        . $self->contact()->real_contact()->display_name();
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
