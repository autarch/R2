package R2::Request;

use strict;
use warnings;

use base 'Catalyst::Request::REST::ForBrowsers';


sub person_params
{
    my $self = shift;

    return $self->_params_for_classes( 'R2::Schema::Person', 'R2::Schema::Contact' );
}


sub _params_for_classes
{
    my $self    = shift;
    my @classes = @_;

    my $params = $self->params();

    my %params;

    for my $class (@classes)
    {
        my $table = $class->Table();

        my %pk = map { $_->name() => 1 } $table->primary_key();

        for my $col ( $table->columns() )
        {
            my $name = $col->name();

            next if $pk{$name};

            next unless exists $params->{$name};

            $params{$name} = $params->{$name};

            delete $params{$name}
                if defined $params{$name} && $params{$name} eq '';
        }
    }

    return %params;
}



1;

