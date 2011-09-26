package R2::Role::Controller::Search;

use Moose::Role;

use namespace::autoclean;

sub _search_params_from_path {
    my $self = shift;
    my $path = shift;

    return unless defined $path;

    my %p;
    for my $pair ( split /;/, $path ) {
        my ( $k, $v ) = split /=/, $pair;

        push @{ $p{$k} }, $v;
    }

    return %p;
}

sub _paging_params {
    my $self = shift;
    my $params = shift;
    my $default_limit = shift;

    my %p;
    for my $key ( qw( page limit order_by reverse_order ) ) {
        $p{$key} = $params->{$key}
            if exists $params->{$key};
    }

    $p{limit} //= $default_limit;

    return %p;
}

1;
