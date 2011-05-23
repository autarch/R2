package R2::Schema::HTMLWidget;

use strict;
use warnings;
use namespace::autoclean;

use R2::CustomFieldType;
use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('HTMLWidget') );
}

sub EnsureRequiredHTMLWidgetsExist {
    my $class = shift;

    for my $name ( map { $_->type() } R2::CustomFieldType->All() ) {
        next if $class->new( name => $name );

        $class->insert(
            name        => $name,
            description => 'default input for ' . $name,
            type        => $name,
        );
    }
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
