package R2::Schema::Address;

use strict;
use warnings;

use List::Util qw( first );
use R2::Schema::AddressType;
use R2::Schema::Contact;
use R2::Schema;
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;

with qw( R2::Role::DataValidator R2::Role::HistoryRecorder );


{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Address') );

    has_one( $schema->table('Contact') );

    has_one 'type' =>
        ( table => $schema->table('AddressType') );

    has_one( $schema->table('Country') );

    has 'city_region_postal_code' =>
        ( is         => 'ro',
          isa        => 'Str|Undef',
          lazy_build => 1,
        );

    has 'summary' =>
        ( is         => 'ro',
          isa        => 'Str',
          lazy_build => 1,
        );
}

sub _build_city_region_postal_code
{
    my $self = shift;

    my $c_r_pc = join ', ', grep { ! string_is_empty($_) } $self->city(), $self->region();

    if ( ! string_is_empty( $self->postal_code() ) )
    {
        $c_r_pc .= q{ } if $c_r_pc;
        $c_r_pc .= $self->postal_code();
    }

    return $c_r_pc;
}

sub _build_summary
{
    my $self = shift;

    my $summary =
        first { ! string_is_empty($_) } map { $self->$_() } qw( street_1 city_region_postal_code );

    return $summary || q{};
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
