package R2::Schema::Address;

use strict;
use warnings;
use namespace::autoclean;

use List::AllUtils qw( first );
use R2::Schema::AddressType;
use R2::Schema::Contact;
use R2::Schema;
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Address') );

    has_one( $schema->table('Contact') );

    has_one 'type' => ( table => $schema->table('AddressType') );

    has 'city_region_postal_code' => (
        is      => 'ro',
        isa     => 'Str|Undef',
        lazy    => 1,
        builder => '_build_city_region_postal_code',
        clearer => '_clear_city_region_postal_code',
    );

    has 'summary' => (
        is      => 'ro',
        isa     => 'Str',
        lazy    => 1,
        builder => '_build_summary',
        clearer => '_clear_summary',
    );
}

with 'R2::Role::Schema::HistoryRecorder';

after update => sub {
    my $self = shift;

    $self->_clear_city_region_postal_code();
    $self->_clear_summary();
};

sub _build_city_region_postal_code {
    my $self = shift;

    my $c_r_pc = join ', ', grep { !string_is_empty($_) } $self->city(),
        $self->region();

    if ( !string_is_empty( $self->postal_code() ) ) {
        $c_r_pc .= q{ } if $c_r_pc;
        $c_r_pc .= $self->postal_code();
    }

    return $c_r_pc;
}

sub _build_summary {
    my $self = shift;

    my $summary = first { !string_is_empty($_) }
    map { $self->$_() } qw( street_1 city_region_postal_code );

    return $summary || q{};
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
