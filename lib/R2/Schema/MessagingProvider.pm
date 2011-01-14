package R2::Schema::MessagingProvider;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema;
use R2::Schema::Contact;
use R2::Schema::MessagingProviderType;
use R2::Schema::Contact;
use R2::Types qw( Maybe Str );

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('MessagingProvider') );

    has_one( $schema->table('Contact') );

    has_one 'type' => ( table => $schema->table('MessagingProviderType') );

    for my $type ( R2::Schema::MessagingProviderType->URITypes() ) {
        has $type => (
            is       => 'ro',
            isa      => Maybe [Str],
            init_arg => undef,
            lazy     => 1,
            default  => sub { $_[0]->type()->$type( $_[0]->screen_name() ) },
        );
    }
}

with 'R2::Role::Schema::HistoryRecorder';

__PACKAGE__->meta()->make_immutable();

1;

__END__
