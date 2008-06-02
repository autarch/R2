package R2::Schema::TimeZone;

use strict;
use warnings;

use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('TimeZone') );

    has_one( $schema->table('Country') );
}

sub CreateDefaultZones
{
    my $class = shift;

    my %zones = ( us =>
                  [ [ 'America/New_York', 'US East Coast' ],
                    [ 'America/Chicago', 'US Midwest' ],
                    [ 'America/Denver', 'US Mountain' ],
                    [ 'America/Los_Angeles', 'US West Coast' ],
                    [ 'America/Anchorage', 'Alaska (Anchorage, Juneau, Nome)' ],
                    [ 'America/Adak', 'Alaska (Adak)' ],
                    [ 'Pacific/Honolulu', 'Hawaii' ],
                    [ 'America/Santo_Domingo', 'Puerto Rico' ],
                    [ 'Pacific/Guam', 'Guam' ],
                  ],

                  ca =>
                  [ [ 'America/Montreal', 'Quebec' ],
                    [ 'America/Toronto', 'Ontario' ],
                    [ 'America/Winnipeg', 'Manitoba' ],
                    [ 'America/Regina', 'Sakatchewan' ],
                    [ 'America/Edmonton', 'Alberta' ],
                    [ 'America/Vancouver', 'British Columbia' ],
                    [ 'America/St_Johns', q{St. John's} ],
                    [ 'America/Halifax', 'Halifax and New Brusnwick' ],
                  ],
                );

    for my $iso_code ( keys %zones )
    {
        my $order = 1;

        for my $zone ( @{ $zones{$iso_code} } )
        {
            $class->insert( olson_name    => $zone->[0],
                            iso_code      => $iso_code,
                            description   => $zone->[1],
                            display_order => $order++,
                          );
        }
    }
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__

