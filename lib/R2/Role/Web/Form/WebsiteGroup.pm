package R2::Role::Web::Form::WebsiteGroup;

use Moose::Role;
use Chloro;

use R2::Types qw( NonEmptyStr );
use R2::Util qw( string_is_empty );

with 'R2::Role::Web::Group::FromSchema' => {
    group            => 'website',
    is_empty_checker => '_website_is_empty',
    classes          => ['R2::Schema::Website'],
    skip             => ['contact_id'],
};

sub _website_is_empty {
    my $self   = shift;
    my $params = shift;
    my $prefix = shift;
    my $group  = shift;

    my @keys = map { join q{.}, $prefix, $_->name() } $group->fields();

    return 1 unless ( grep { !string_is_empty( $params->{$_} ) } @keys ) > 1;
    return 0;
}

1;
