use strict;
use warnings;

use Test::More;

use lib 't/lib';
use R2::Test qw( mock_schema );

use R2::Schema::Address;

mock_schema();

{
    my @tests = (
        [
            {
                city        => q{},
                region      => q{},
                postal_code => q{},
            },
            q{}
        ],
        [
            {
                city        => q{Minneapolis},
                region      => q{},
                postal_code => q{},
            },
            'Minneapolis'
        ],
        [
            {
                city        => q{},
                region      => q{MN},
                postal_code => q{},
            },
            'MN'
        ],
        [
            {
                city        => q{},
                region      => q{},
                postal_code => q{55408},
            },
            '55408'
        ],
        [
            {
                city        => q{Minneapolis},
                region      => q{MN},
                postal_code => q{},
            },
            'Minneapolis, MN'
        ],
        [
            {
                city        => q{Minneapolis},
                region      => q{},
                postal_code => q{55408},
            },
            'Minneapolis 55408'
        ],
        [
            {
                city        => q{},
                region      => q{MN},
                postal_code => q{55408},
            },
            'MN 55408'
        ],
        [
            {
                city        => q{Minneapolis},
                region      => q{MN},
                postal_code => q{55408},
            },
            'Minneapolis, MN 55408'
        ],
    );

    for my $test (@tests) {
        my $address = R2::Schema::Address->new(
            address_id => 1,
            %{ $test->[0] },
            contact_id      => 1,
            address_type_id => 1,
            iso_code        => 'us',
            _from_query     => 1,
        );

        my $desc = join ', ',
            map {"$_ = '$test->[0]{$_}'"} qw( city region postal_code );

        is(
            $address->city_region_postal_code(), $test->[1],
            qq{city_region_postal_code with $desc - '$test->[1]'}
        );
    }
}

{
    my @tests = (
        [
            {
                street_1    => q{},
                city        => q{},
                region      => q{},
                postal_code => q{},
            },
            q{}
        ],
        [
            {
                street_1    => q{},
                city        => q{Minneapolis},
                region      => q{},
                postal_code => q{},
            },
            'Minneapolis'
        ],
        [
            {
                street_1    => '300 Some Street',
                city        => q{},
                region      => q{},
                postal_code => q{},
            },
            '300 Some Street'
        ],
        [
            {
                street_1    => '300 Some Street',
                city        => q{},
                region      => q{MN},
                postal_code => q{},
            },
            '300 Some Street'
        ],
    );

    for my $test (@tests) {
        my $address = R2::Schema::Address->new(
            address_id => 1,
            %{ $test->[0] },
            contact_id      => 1,
            address_type_id => 1,
            iso_code        => 'us',
            _from_query     => 1,
        );

        my $desc = join ', ',
            map { qq{$_ = '} . $address->$_() . q{'} }
            qw( street_1 city_region_postal_code );

        is(
            $address->summary(), $test->[1],
            qq{summary with $desc - '$test->[1]'}
        );
    }
}

{
    my $address = R2::Schema::Address->new(
        address_id      => 1,
        street_1        => '100 Some St',
        city            => 'Opolis',
        region          => 'MN',
        postal_code     => '55555',
        contact_id      => 1,
        address_type_id => 1,
        iso_code        => 'us',
        _from_query     => 1,
    );

    is(
        $address->city_region_postal_code,
        'Opolis, MN 55555',
        'city_region_postal_code before update'
    );

    is(
        $address->summary(),
        '100 Some St',
        'summary before update'
    );

    $address->update(
        street_1    => '101 Other St',
        city        => 'Mopolis',
        region      => 'CA',
        postal_code => '99999',
    );

    is(
        $address->city_region_postal_code,
        'Mopolis, CA 99999',
        'city_region_postal_code after update'
    );

    is(
        $address->summary(),
        '101 Other St',
        'summary after update'
    );
}

done_testing();
