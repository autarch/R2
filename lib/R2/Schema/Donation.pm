package R2::Schema::Donation;

use strict;
use warnings;

use DateTime::Format::Pg;
use DateTime::Format::Strptime;
use R2::Schema::DonationSource;
use R2::Schema::DonationTarget;
use R2::Schema;
use R2::Util qw( string_is_empty );
use Scalar::Util qw( looks_like_number );

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with 'R2::Role::DataValidator', 'R2::Role::URIMaker';


{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Donation') );

    transform 'donation_date' =>
        deflate { blessed $_[1] ? DateTime::Format::Pg->format_date( $_[1] ) : $_[1] },
        inflate { defined $_[1] ? DateTime::Format::Pg->parse_date( $_[1] ) : $_[1] };

    has_one source =>
        ( table => $schema->table('DonationSource') );

    has_one target =>
        ( table => $schema->table('DonationTarget') );

    has_one payment_type =>
        ( table => $schema->table('PaymentType') );

    has_one( $schema->table('Contact') );

    class_has '_ValidationSteps' =>
        ( is      => 'ro',
          isa     => 'ArrayRef[Str]',
          lazy    => 1,
          default => sub { [ qw( _validate_amount _valid_donation_date ) ] },
        );
}

sub _validate_amount
{
    my $self = shift;
    my $p    = shift;

    # remove any currency symbols and such
    $p->{amount} =~ s/^[^\d\-](\d)/$1/;

    # will be caught later
    return if string_is_empty( $p->{amount} );

    my $msg;

    if ( ! looks_like_number( $p->{amount} ) )
    {
        $msg = "The amount you specified ($p->{amount}) does not seem to be a number.";
    }
    elsif ( $p->{amount} <= 0 )
    {
        $msg = "You cannot have a negative amount for a donation.";
    }
    elsif ( sprintf( '%.2f', $p->{amount} ) != $p->{amount} )
    {
        $msg = "You cannot have more than two digits to the right of the decimal point.";
    }

    return unless $msg;

    return { message => $msg,
             field   => 'amount',
           };
}

sub _valid_donation_date
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    my $format = delete $p->{date_format} || '%y-%m-%d';

    return if string_is_empty( $p->{donation_date} );

    return if blessed $p->{donation_date};

    my $parser = DateTime::Format::Strptime->new( pattern   => $format,
                                                  time_zone => 'floating',
                                                );

    my $dt = $parser->parse_datetime( $p->{donation_date} );

    return { field   => 'donation_date',
             message => 'This does not seem to be a valid date.',
           }
        unless $dt;

    return;
}

sub _base_uri_path
{
    my $self = shift;

    return $self->contact()->_base_uri_path() . '/donation/' . $self->donation_id();
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
