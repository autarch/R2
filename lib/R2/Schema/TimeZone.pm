package R2::Schema::TimeZone;

use strict;
use warnings;
use namespace::autoclean;

use Fey::Object::Iterator::FromSelect;
use R2::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('TimeZone') );

    class_has '_ByCountrySQL' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        lazy    => 1,
        builder => '_BuildByCountrySQL',
    );
}

with 'R2::Role::Schema::HasDisplayOrder' =>
    { related_column => __PACKAGE__->Table()->column('country') };

sub EnsureRequiredTimeZonesExist {
    my $class = shift;

    my %zones = (
        'United States' => [
            [ 'America/New_York',      'US East Coast' ],
            [ 'America/Chicago',       'US Midwest' ],
            [ 'America/Denver',        'US Mountain' ],
            [ 'America/Los_Angeles',   'US West Coast' ],
            [ 'America/Anchorage',     'Alaska (Anchorage, Juneau, Nome)' ],
            [ 'America/Adak',          'Alaska (Adak)' ],
            [ 'Pacific/Honolulu',      'Hawaii' ],
            [ 'America/Santo_Domingo', 'Puerto Rico' ],
            [ 'Pacific/Guam',          'Guam' ],
        ],

        'Canada' => [
            [ 'America/Montreal',  'Quebec' ],
            [ 'America/Toronto',   'Ontario' ],
            [ 'America/Winnipeg',  'Manitoba' ],
            [ 'America/Regina',    'Sakatchewan' ],
            [ 'America/Edmonton',  'Alberta' ],
            [ 'America/Vancouver', 'British Columbia' ],
            [ 'America/St_Johns',  q{St. John's} ],
            [ 'America/Halifax',   'Halifax and New Brunswick' ],
        ],
    );

    for my $country ( keys %zones ) {
        for my $zone ( @{ $zones{$country} } ) {
            next if $class->new( olson_name => $zone->[0] );

            $class->insert(
                olson_name  => $zone->[0],
                description => $zone->[1],
                country     => $country,
            );
        }
    }
}

sub ByCountry {
    my $class   = shift;
    my $country = shift;

    my $select = $class->_ByCountrySQL();

    my $dbh = $class->_dbh($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes     => $class,
        dbh         => $dbh,
        select      => $select,
        bind_params => [$country],
    );
}

sub _BuildByCountrySQL {
    my $class = __PACKAGE__;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('TimeZone') )
        ->from( $schema->tables('TimeZone') )->where(
        $schema->table('TimeZone')->column('country'),
        '=', Fey::Placeholder->new()
        )->order_by( $schema->table('TimeZone')->column('display_order') );

    return $select;

}

__PACKAGE__->meta()->make_immutable();

1;

__END__

