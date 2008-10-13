package R2::Schema::Address;

use strict;
use warnings;

use R2::Schema::AddressType;
use R2::Schema::Contact;
use R2::Schema;
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;

with qw( R2::Role::DataValidator R2::Role::HistoryRecorder );


{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Address') );

    has_one( $schema->table('Contact') );

    has_one 'type' =>
        ( table => $schema->table('AddressType') );

    has_one( $schema->table('Country') );

    has 'city_region_postal_code' =>
        ( is      => 'ro',
          isa     => 'Str|Undef',
          lazy    => 1,
          builder => '_build_city_region_postal_code',
        );
}

sub _build_city_region_postal_code
{
    my $self = shift;

    my $c_r_pc = join ', ', grep { ! string_is_empty($_) } $self->city(), $self->region();
    $c_r_pc .= q{ } if $c_r_pc;
    $c_r_pc .= $self->postal_code() if ! string_is_empty( $self->postal_code() );

    return $c_r_pc;
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
