package R2::Schema::ContactParticipation;

use strict;
use warnings;
use namespace::autoclean;

use DateTime::Format::Natural;
use R2::Schema;
use R2::Schema::Contact;
use R2::Types qw( NonEmptyStr );
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator';
with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('ContactParticipation') );

    has_one( $schema->table('Activity') );

    has_one type => ( table => $schema->table('ParticipationType') );

    has_one( $schema->table('Contact') );
}

sub _base_uri_path {
    my $self = shift;

    return
          $self->activity()->_base_uri_path()
        . '/participation/'
        . $self->contact_participation_id();

}

__PACKAGE__->meta()->make_immutable();

1;

__END__
