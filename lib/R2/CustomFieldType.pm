package R2::CustomFieldType;

use strict;
use warnings;

use R2::Schema;

use List::AllUtils qw( first );
use Moose;
use MooseX::ClassAttribute;
use Moose::Util::TypeConstraints;

# The array preserves a specific order (for use in forms and such)
my @Types =
    ( [ 'Text'     => 'text of any sort' ],
      [ 'Integer'  => 'an integer (1, 42, 0, -210, etc.)' ],
      [ 'Float'    => 'a decimal number (1.0, 610.42, -0.02, etc.)' ],
      [ 'Date'     => 'a date without a time' ],
      [ 'DateTime' => 'a date and time' ],
      [ 'File'     => 'an attachment (image, Word doc, PDF, etc.)' ],
      [ 'SingleSelect' => 'pick one option from a pre-defined list' ],
      [ 'MultiSelect'  => 'pick any number of options from a pre-defined list' ],
    );

my %Descriptions = map { @{$_} } @Types;

has 'type' =>
    ( is       => 'ro',
      isa      => ( enum [ map { $_->[0] } @Types ] ),
      required => 1,
    );

has 'description' =>
    ( is       => 'ro',
      isa      => 'Str',
      lazy     => 1,
      default  => sub { $Descriptions{ $_[0]->type() } },
      init_arg => undef,
    );

has 'table' =>
    ( is       => 'ro',
      isa      => 'Str',
      lazy     => 1,
      default  => sub { 'CustomField' . $_[0]->type() . 'Value' },
      required => 1,
      init_arg => undef,
    );

has 'default_widget' =>
    ( is         => 'ro',
      isa        => 'R2::Schema::HTMLWidget',
      lazy_build => 1,
    );

has 'html_widgets' =>
    ( is         => 'ro',
      isa        => 'ArrayRef[R2::Schema::HTMLWidget]',
      lazy_build => 1,
    );

has '_cleaner' =>
    ( is      => 'ro',
      isa     => 'CodeRef',
      default => sub { sub { $_[1] } },
    );

has '_validator' =>
    ( is      => 'ro',
      isa     => 'CodeRef',
      default => sub { sub { 1 } },
    );

class_has 'Types' =>
    ( is         => 'ro',
      isa        => 'ArrayRef',
      lazy_build => 1,
    );

sub _build_Types
{
    my $class = shift;

    # It'd be more correct to look at the enum in the database, but
    # this gets looked at when some classes are loaded, and I _hate_
    # requiring a connected database handle just to compile a class.
    return [ map { $_->[0] } @Types ];
}

{
    my @All;

    sub All
    {
        my $class = shift;

        return @All if @All;

        @All = map { $class->new( type => $_ ) } @{ $class->Types() };

        return @All;
    }
}

sub _build_default_html_widgets
{
    my $self = shift;

    my $calm_name = studly_to_calm( $self->type() );

    return first { $_->name() eq $calm_name } @{ $self->html_widgets() };
}

sub _build_html_widgets
{
    return [];
}

sub clean_value
{
    return $_[0]->_cleaner()->( $_[1] );
}

sub value_is_valid
{
    return $_[0]->_validator()->( $_[1] );
}

no Moose;
no MooseX::ClassAttribute;
no Moose::Util::TypeConstraints;

__PACKAGE__->meta()->make_immutable();

1;
