package R2::Schema::Person;

use strict;
use warnings;

use DateTime::Format::Pg;
use DateTime::Format::Strptime;
use R2::Schema;
use R2::Schema::Contact;
use R2::Schema::PersonMessaging;
use R2::Util qw( string_is_empty );
use Scalar::Util qw( blessed );

use MooseX::ClassAttribute;
use Fey::ORM::Table;

with 'R2::Role::DVAAC';


{
    my $schema = R2::Schema->Schema();

    my $person_t = $schema->table('Person');

    has_table $person_t;

    transform 'birth_date' =>
        deflate { blessed $_[0] ? DateTime::Format::Pg->format_date( $_[0] ) : $_[0] },
        inflate { defined $_[0] ? DateTime::Format::Pg->parse_date( $_[0] ) : $_[0] };

    has_one 'contact' =>
        ( table   => $schema->table('Contact'),
          handles => [ qw( addresses phone_numbers ),
                       ( grep { ! __PACKAGE__->meta()->has_attribute($_) }
                         R2::Schema::Contact->meta()->get_attribute_list(),
                       )
                     ],
        );

    has_one 'user' =>
        ( table => $schema->table('User'),
          undef => 1,
        );

    # XXX - this'd be nicer if it selected the messaging provider in
    # the same query
    has_many 'messaging' =>
        ( table       => $schema->table('PersonMessaging'),
          cache       => 1,
          select      => __PACKAGE__->_MessagingSelect(),
          bind_params => sub { $_[0]->person_id() },
        );

    class_has 'GenderValues' =>
        ( is      => 'ro',
          isa     => 'ArrayRef',
          lazy    => 1,
          default => \&_GetGenderValues,
        );

    class_has '_ValidationSteps' =>
        ( is      => 'ro',
          isa     => 'ArrayRef[Str]',
          lazy    => 1,
          default => sub { [ qw( _require_some_name _valid_birth_date ) ] },
        );
}

sub _GetGenderValues
{
    my $class = shift;

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    my $sth = $dbh->column_info( '', '', 'Person', 'gender' );

    my $col_info = $sth->fetchall_arrayref({})->[0];

    return $col_info->{pg_enum_values} || [];
}

sub _require_some_name
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    if ($is_insert)
    {
        return unless
            string_is_empty( $p->{first_name} ) && string_is_empty( $p->{last_name} );
    }
    else
    {
        return unless
            exists $p->{first_name} && exists $p->{last_name}
            && string_is_empty( $p->{first_name} ) && string_is_empty( $p->{last_name} );

    }

    return { message => 'A person requires either a first or last name.' };
}

sub _valid_birth_date
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    my $format = delete $p->{date_format};

    return if string_is_empty( $p->{birth_date} );

    my $dt;
    if ( blessed $p->{birth_date} )
    {
        $dt = $p->{birth_date};
    }
    else
    {
        my $parser = DateTime::Format::Strptime->new( pattern   => $format,
                                                      time_zone => 'floating',
                                                    );

        $dt = $parser->parse_datetime( $p->{birth_date} );

        return { field   => 'birth_date',
                 message => 'Birth date does not seem to be a valid date.',
               }
            unless $dt;
    }

    return if DateTime->today( time_zone => 'floating' ) >= $dt;

    return { field   => 'birth_date',
             message => 'Birth date cannot be in the future.',
           };
}

sub _MessagingSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('PersonMessaging') )
           ->from( $schema->tables( 'PersonMessaging', 'MessagingProvider' ) )
           ->where( $schema->table('PersonMessaging')->column('person_id'),
                    '=', Fey::Placeholder->new() )
           ->order_by( $schema->table('MessagingProvider')->column('name'), 'ASC' );

    return $select;
}

sub friendly_name
{
    my $self = shift;

    return $self->first_name();
}

sub full_name
{
    my $self = shift;

    return
        ( join ' ',
          grep { ! string_is_empty($_) }
          map { $self->$_() }
          qw( salutation first_name middle_name last_name suffix )
        );

}

no Fey::ORM::Table;
no Moose;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__
