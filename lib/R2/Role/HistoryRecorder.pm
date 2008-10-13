package R2::Role::HistoryRecorder;

use strict;
use warnings;

use R2::Schema::ContactHistory;
use R2::Schema::ContactHistoryType;
use Storable qw( nfreeze );

use Moose::Role;

#requires_attr 'contact_id';

requires qw( insert update delete );


around 'insert' => sub
{
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    my $user = delete $p{user};

    my $row = $class->$orig(%p);

    return $row unless $user;

    my %history_p =
        ( map { $_ => $row->$_() }
          grep { $row->can($_) }
          qw( contact_id email_address_id website_id address_id phone_number_id )
        );

    my $notes = 'Added a new ' . $class->_class_description();

    my $type;
    if ( $row->does('R2::Role::ActsAsContact' ) )
    {
        $type = R2::Schema::ContactHistoryType->Created();
    }
    else
    {
        ( my $thing = $class ) =~ s/^R2::Schema:://;

        my $type_name = 'Add' . $thing;

        $type = R2::Schema::ContactHistoryType->$type_name();
    }

    my @pk = map { $_->name() } @{ $class->Table()->primary_key() };

    my $reversal = { class              => $class,
                     constructor_params => { map { $_ => $row->$_() } @pk },
                     method             => 'delete',
                   };

    R2::Schema::ContactHistory->insert
        ( %history_p,
          user_id                 => $user->user_id(),
          contact_history_type_id => $type->contact_history_type_id(),
          notes                   => $notes,
          reversal_blob           => nfreeze($reversal),
        );
};

sub _class_description
{
    my $class = ref $_[0] || $_[0];

    ( my $string = $class ) =~ s/R2::Schema:://;

    $string =~ s/(^|.)([A-Z])/$1 ? "$1\L_$2" : "\L$2"/ge;

    return $string;
}

no Moose::Role;

1;
