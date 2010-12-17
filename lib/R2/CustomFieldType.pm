package R2::CustomFieldType;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema;

use List::AllUtils qw( first );
use Moose;
use MooseX::ClassAttribute;
use Moose::Util::TypeConstraints;

# The array preserves a specific order (for use in forms and such)
my @Types = (
    [ 'Text'         => 'text of any sort' ],
    [ 'Integer'      => 'an integer (1, 42, 0, -210, etc.)' ],
    [ 'Decimal'      => 'a decimal number (1.0, 610.42, -0.02, etc.)' ],
    [ 'Date'         => 'a date without a time' ],
    [ 'DateTime'     => 'a date and time' ],
    [ 'File'         => 'an attachment (image, Word doc, PDF, etc.)' ],
    [ 'SingleSelect' => 'pick one option from a pre-defined list' ],
    [ 'MultiSelect' => 'pick any number of options from a pre-defined list' ],
);

my %Descriptions = map { @{$_} } @Types;

has 'type' => (
    is       => 'ro',
    isa      => ( enum [ map { $_->[0] } @Types ] ),
    required => 1,
);

has 'description' => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    default  => sub { $Descriptions{ $_[0]->type() } },
    init_arg => undef,
);

has 'table' => (
    is      => 'ro',
    isa     => 'Fey::Table',
    lazy    => 1,
    default => sub {
        R2::Schema->Schema()
            ->table( 'CustomField' . $_[0]->type() . 'Value' );
    },
    init_arg => undef,
);

has 'default_widget' => (
    is      => 'ro',
    isa     => 'R2::Schema::HTMLWidget',
    lazy    => 1,
    builder => '_build_default_widget',
);

has 'html_widgets' => (
    is      => 'ro',
    isa     => 'ArrayRef[R2::Schema::HTMLWidget]',
    lazy    => 1,
    builder => '_build_html_widgets',
);

has 'is_select' => (
    is      => 'ro',
    isa     => 'Bool',
    default => sub { $_[0]->type() =~ /Select/ ? 1 : 0 },
);

class_has 'Types' => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_BuildTypes',
);

sub _BuildTypes {
    my $class = shift;

    # It'd be more correct to look at the enum in the database, but
    # this gets looked at when some classes are loaded, and I _hate_
    # requiring a connected database handle just to compile a class.
    return [ map { $_->[0] } @Types ];
}

{
    my @All;

    sub All {
        my $class = shift;

        return @All if @All;

        @All = map { $class->new( type => $_ ) } @{ $class->Types() };

        return @All;
    }
}

sub _build_default_html_widgets {
    my $self = shift;

    my $calm_name = studly_to_calm( $self->type() );

    return first { $_->name() eq $calm_name } @{ $self->html_widgets() };
}

sub _build_html_widgets {
    return [];
}

sub clean_value {
    return $_[1];
}

sub value_is_valid {
    return 1;
}

__PACKAGE__->meta()->make_immutable();

1;
