package R2::Web::Util;

use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( format_note );

use Markdent::Simple::Fragment;
use R2::Util qw( string_is_empty );

my $mds = Markdent::Simple::Fragment->new();

sub format_note {
    my $note = shift;

    return q{} if string_is_empty($note);

    return $mds->markdown_to_html( markdown => $note );
}

1;
