package R2::Schema::Activity;

use Fey::ORM::Table;

use namespace::autoclean;

use Fey::Placeholder;
use R2::Schema;

with 'R2::Role::Schema::DataValidator';
with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Activity') );

    has_one( $schema->table('Account') );

    has_one type => ( table => $schema->table('ActivityType') );

    query contact_count => (
        select      => __PACKAGE__->_BuildContactCountSelect(),
        bind_params => sub { $_[0]->activity_id() },
    );
}

sub _BuildContactCountSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $count = Fey::Literal::Function->new(
        'COUNT',
        Fey::Literal::Function->new(
            'DISTINCT',
            $schema->table('ContactParticipation')->column('contact_id')
        )
    );

    #<<<
    $select
        ->select($count)
        ->from  ( $schema->table('ContactParticipation') )
        ->where ( $schema->table('ContactParticipation')->column('activity_id'),
                  '=', Fey::Placeholder->new() );
    #>>>
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
