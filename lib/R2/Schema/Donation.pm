package R2::Schema::Donation;

use strict;
use warnings;

use R2::Schema::DonationSource;
use R2::Schema::DonationTarget;
use R2::Schema;
use R2::Util qw( string_is_empty );
use Scalar::Util qw( looks_like_number );

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with 'R2::Role::DataValidator';


{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Donation') );

    has_one source =>
        ( table => $schema->table('DonationSource') );

    has_one target =>
        ( table => $schema->table('DonationTarget') );

    has_one( $schema->table('PaymentType') );

    has_one( $schema->table('Contact') );

    class_has '_ValidationSteps' =>
        ( is      => 'ro',
          isa     => 'ArrayRef[Str]',
          lazy    => 1,
          default => sub { [ qw( _validate_amount ) ] },
        );
}

sub _validate_amount
{
    my $self = shift;
    my $p    = shift;

    # remove any currency symbols and such
    $p->{amount} =~ s/^\D+(\d)/$1/;

    # will be caught later
    return if string_is_empty( $p->{amount} );

    my $msg;

    if ( ! looks_like_number( $p->{amount} ) )
    {
        $msg = "The amount you specified ($p->{amount}) does not seem to be a number.";
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

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
