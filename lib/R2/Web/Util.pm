package R2::Web::Util;

use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( table_to_chloro_fields format_note );

use Markdent::Simple::Fragment;
use R2::Types qw( Bool Int Num Str );
use R2::Util qw( string_is_empty );

my $mds = Markdent::Simple::Fragment->new();

sub format_note {
    my $note = shift;

    return q{} if string_is_empty($note);

    return $mds->markdown_to_html( markdown => $note );
}

sub table_to_chloro_fields {
    my $table = shift;

    # We don't want to change the reference being passed
    my %skip = %{ shift || {} };

    $skip{ $_->name() } = 1 for @{ $table->primary_key() };

    return map { _column_to_chloro_field($_) }
        grep   { !$skip{ $_->name() } } $table->columns();
}

sub _column_to_chloro_field {
    my $column = shift;

    my %field = (
        name => $column->name(),
        isa  => _type_for_column($column),
    );

    $field{required} = 1
        unless $column->is_nullable()
            || (   $column->default()
                && $column->default()->isa('Fey::Literal::String')
                && $column->default()->string() eq q{} );

    $field{extractor} = '_datetime_from_str'
        if $field{isa} eq 'DateTime';

    return Chloro::Field->new(%field);
}

{
    my %map = (
        text          => Str,
        blob          => Str,
        EMAIL_ADDRESS => Str,
        integer       => Int,
        float         => Num,
        boolean       => Bool,
        date          => 'DateTime',
        datetime      => 'DateTime',
    );

    sub _type_for_column {
        my $column = shift;

        my $sql_type = $column->generic_type();
        my $pg_type  = uc $column->type();

        return ( $map{$sql_type} || $map{$pg_type} )
            || die
            "Cannot translate SQL type of $sql_type ($pg_type) to Moose type";
    }
}

1;
