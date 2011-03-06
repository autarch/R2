package R2::Schema::Activity;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

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

    query participation_count => (
        select      => __PACKAGE__->_BuildParticipationCountSelect(),
        bind_params => sub { $_[0]->activity_id() },
    );

    has participations => (
        is      => 'ro',
        isa     => 'Fey::Object::Iterator::FromSelect',
        lazy    => 1,
        builder => '_build_participations',
    );

    class_has '_ParticipationsSelect' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        builder => '_BuildParticipationsSelect',
    );
}

sub _BuildParticipationCountSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $count = Fey::Literal::Function->new(
        'COUNT',
        $schema->table('ContactParticipation')->column('contact_id')
    );

    #<<<
    $select
        ->select($count)
        ->from  ( $schema->table('ContactParticipation') )
        ->where ( $schema->table('ContactParticipation')->column('activity_id'),
                  '=', Fey::Placeholder->new() );
    #>>>

    return $select;
}

sub _build_participations {
    my $self = shift;

    my $select = $self->_ParticipationsSelect();

    my $dbh = $self->_dbh($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes =>
            [qw( R2::Schema::Contact R2::Schema::ContactParticipation )],
        dbh         => $dbh,
        select      => $select,
        bind_params => [ $self->activity_id() ],
    );
}

sub _BuildParticipationsSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select
        ->select( $schema->tables( 'Contact', 'ContactParticipation' ) )
        ->from( $schema->tables( 'Contact', 'ContactParticipation' ) )
        ->where ( $schema->table('ContactParticipation')->column('activity_id'),
                  '=', Fey::Placeholder->new() )
        ->order_by( $schema->table('ContactParticipation')->column('start_date'),
                    'DESC' );
    #>>>

    return $select;
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
