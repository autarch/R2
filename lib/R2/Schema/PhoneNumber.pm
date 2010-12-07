package R2::Schema::PhoneNumber;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema::Contact;
use R2::Schema::PhoneNumberType;
use R2::Schema;

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator';
with 'R2::Role::Schema::HistoryRecorder';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('PhoneNumber') );

    has_one( $schema->table('Contact') );

    has_one 'type' => ( table => $schema->table('PhoneNumberType') );
}

sub summary { $_[0]->type()->name() . q{: } . $_[0]->phone_number() }

__PACKAGE__->meta()->make_immutable();

1;

__END__
