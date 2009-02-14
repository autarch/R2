package R2::Schema::HTMLWidget;

use strict;
use warnings;

use R2::CustomFieldType;
use R2::Schema;

use Fey::ORM::Table;


{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('HTMLWidget') );
}

sub CreateDefaultWidgets
{
    my $class = shift;

    for my $name ( map { $_->type() } R2::CustomFieldType->All() )
    {
        $class->insert( name        => $name,
                        description => 'default input for ' . $name,
                        type        => $name,
                      );
    }
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
