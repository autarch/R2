package R2::Schema::TimeZone;

use strict;
use warnings;

use Fey::Object::Iterator;
use R2::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('TimeZone') );

    has_one( $schema->table('Country') );

    class_has '_SelectByCountrySQL' =>
        ( is      => 'ro',
          isa     => 'Fey::SQL::Select',
          lazy    => 1,
          default => \&_MakeSelectByCountrySQL,
        );
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

sub ByCountry
{
    my $class    = shift;
    my $iso_code = shift;

    my $select = $class->_SelectByCountrySQL();

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    my $sth = $dbh->prepare( $select->sql($dbh) );

    return
        Fey::Object::Iterator->new( classes     => $class,
                                    handle      => $sth,
                                    bind_params => [ $iso_code ],
                                  );
}

sub _MakeSelectByCountrySQL
{
    my $class = __PACKAGE__;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('TimeZone') )
           ->from( $schema->tables( 'TimeZone') )
           ->where( $schema->table('TimeZone')->column('iso_code'),
                    '=', Fey::Placeholder->new() )
           ->order_by( $schema->table('TimeZone')->column('display_order') );

    return $select;

}


no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__

