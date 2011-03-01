package R2::Schema::Activity;

use Fey::ORM::Table;

use namespace::autoclean;

use R2::Schema;

with 'R2::Role::Schema::DataValidator';
with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Activity') );

    has_one( $schema->table('Account') );

    has_one type => ( table => $schema->table('ActivityType') );
}

sub _base_uri_path {
    my $self = shift;

    return
          $self->account()->_base_uri_path()
        . '/activity/'
        . $self->activity_id();
}

__PACKAGE__->meta()->make_immutable();

1;
