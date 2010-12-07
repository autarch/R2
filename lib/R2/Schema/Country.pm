package R2::Schema::Country;

use strict;
use warnings;
use namespace::autoclean;

use Locale::Country qw( all_country_codes code2country );
use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Country') );
}

sub EnsureRequiredCountriesExist {
    for my $code ( all_country_codes() ) {
        next if __PACKAGE__->new( iso_code => $code );

        __PACKAGE__->insert(
            iso_code => $code,
            name     => code2country($code),
        );
    }
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
