package R2::Schema::Donation;

use strict;
use warnings;
use namespace::autoclean;

use DateTime::Format::Natural;
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
with 'R2::Role::Schema::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Donation') );

    has_one source => ( table => $schema->table('DonationSource') );

    has_one campaign => ( table => $schema->table('DonationCampaign') );

    has_one( $schema->table('PaymentType') );

    has_one( $schema->table('Contact') );

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
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if string_is_empty( $p->{donation_date} );

    return if blessed $p->{donation_date};

    my $parser = DateTime::Format::Natural->new(
        time_zone => 'floating',
    );

    my $dt = $parser->parse_datetime( $p->{donation_date} );

    return {
        field   => 'donation_date',
        message => 'This does not seem to be a valid date.',
        }
        unless $dt && !$parser->error();

    $p->{donation_date} = $dt;

    return;
}

sub _valid_receipt_date {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if string_is_empty( $p->{receipt_date} );

    return if blessed $p->{receipt_date};

    my $parser = DateTime::Format::Natural->new(
        time_zone => 'floating',
    );

    my $dt = $parser->parse_datetime( $p->{receipt_date} );

    return {
        field   => 'donation_date',
        message => 'This does not seem to be a valid date.',
        }
        unless $dt && !$parser->error();

    $p->{receipt_date} = $dt;

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
        . $self->contact()->real_contact()->full_name();
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
