package R2::Web::Session;

use strict;
use warnings;

use R2::Types;

use Moose;
use MooseX::AttributeHelpers;
use MooseX::Params::Validate qw( pos_validated_list );
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has form =>
    ( is        => 'rw',
      isa       => 'Chloro::Object',
      predicate => 'has_form',
    );

has _errors =>
    ( metaclass => 'Collection::Array',
      is        => 'ro',
      isa       => 'ArrayRef[R2.Type.NonEmptyStr]',
      default   => sub { [] },
      init_arg  => undef,
      provides  => { push     => 'add_error',
                     elements => 'errors',
                   },
    );

has _messages =>
    ( metaclass => 'Collection::Array',
      is        => 'ro',
      isa       => 'ArrayRef[R2.Type.NonEmptyStr]',
      default   => sub { [] },
      init_arg  => undef,
      provides  => { push     => 'add_message',
                     elements => 'messages',
                   },
    );

around add_error => sub
{
    my $orig = shift;
    my $self = shift;

    return $self->$orig( map { $self->_error_text($_) } @_ );
};

sub _error_text
{
    my $self = shift;
    my $e    = pos_validated_list( \@_, { isa => 'R2.Type.ErrorForSession' } );

    if ( eval { $e->can('messages') } && $e->messages() )
    {
        return $e->messages();
    }
    elsif ( eval { $e->can('message') } )
    {
        return $e->message();
    }
    elsif ( ref $e )
    {
        return @{ $e };
    }
    else
    {
        # force stringification
        return $e . q{};
    }
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
