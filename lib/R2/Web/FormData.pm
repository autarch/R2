package R2::Web::FormData;

use strict;
use warnings;

use Scalar::Util qw( blessed );

use Params::Validate
    qw( validate_pos HASHREF OBJECT );


sub new
{
    my $class = shift;
    validate_pos( @_, ( { type => HASHREF | OBJECT } ) x @_ );

    return bless { sources => \@_ }, $class;
}

sub has_sources
{
    return scalar @{ $_[0]->{sources} };
}

sub param
{
    my $self  = shift;
    my $param = shift;

    foreach my $s ( @{ $self->{sources} } )
    {
        if ( blessed $s )
        {
            return $s->$param() if $s->can($param);
        }
        else
        {
            return $s->{$param} if exists $s->{$param};
        }
    }

    return;
}


1;

__END__
