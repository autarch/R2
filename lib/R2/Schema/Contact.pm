package R2::Schema::Contact;

use strict;
use warnings;

use Data::Validate::Domain qw( is_domain );
use Fey::Literal::String;
use Fey::Placeholder;
use R2::Image;
use R2::Schema;
use R2::Schema::Address;
use R2::Schema::File;
use R2::Schema::PhoneNumber;
use R2::Util qw( string_is_empty );
use URI;
use URI::http;

# cannot load these because of circular dependency problems
#use R2::Schema::Household;
#use R2::Schema::Organization;
#use R2::Schema::Person;
#use R2::Schema::Account;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with 'R2::Role::DataValidator';


{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Contact') );

    transform 'website' =>
        deflate { blessed $_[1] ? $_[1]->canonical() . '' : $_[1] },
        inflate { defined $_[1] ? URI->new( $_[1] ) : $_[1] };

    has_one( $schema->table('Account') );

    for my $type ( qw( person household organization ) )
    {
        has_one $type =>
            ( table => $schema->table( ucfirst $type ),
              undef => 1,
            );

        has 'is_' . $type =>
            ( is       => 'ro',
              isa      => 'Bool',
              lazy     => 1,
              default  => sub { $_[0]->contact_type() eq ucfirst $type ? 1 : 0 },
              init_arg => undef,
            );
    }

    has_one '_file' =>
        ( table => $schema->table('File') );

    has 'image' =>
        ( is      => 'ro',
          isa     => 'R2::Image|Undef',
          lazy    => 1,
          default => sub { my $file = $_[0]->_file
                               or return;
                           return R2::Image->new( file => $file ) },
        );

    has_many 'addresses' =>
        ( table    => $schema->table('Address'),
          order_by => [ $schema->table('Address')->column('is_preferred'),
                        'DESC',
                        $schema->table('Address')->column('iso_code'),
                        'ASC',
                        $schema->table('Address')->column('region'),
                        'ASC',
                        $schema->table('Address')->column('city'),
                        'ASC',
                      ],
          cache    => 1,
        );

    has_one 'primary_address' =>
        ( table       => $schema->table('Address'),
          select      => __PACKAGE__->_PrimaryAddressSelect(),
          bind_params => sub { $_[0]->contact_id() }
        );

    has_many 'phone_numbers' =>
        ( table => $schema->table('PhoneNumber'),
          cache => 1,
        );

    has_one 'primary_phone_number' =>
        ( table       => $schema->table('PhoneNumber'),
          select      => __PACKAGE__->_PrimaryPhoneNumberSelect(),
          bind_params => sub { $_[0]->contact_id() }
        );

    class_has '_ValidationSteps' =>
        ( is      => 'ro',
          isa     => 'ArrayRef[Str]',
          lazy    => 1,
          default => sub { [ qw( _valid_email_address _canonicalize_website ) ] },
        );
}

before 'update' => sub
{
    my $self = shift;
    my %p    = @_;

    my $person = $self->person()
        or return;

    die 'Cannot remove an email address for a user'
        if    exists $p{email_address}
           && ! defined $p{email_address}
           && $person->user();
};

sub _valid_email_address
{
    my $self      = shift;
    my $p         = shift;

    return if string_is_empty( $p->{email_address} );

    my ( $name, $domain ) = split /\@/, $p->{email_address};

    return
        if ( ! string_is_empty($name)
             && $name =~ /^[^@]+$/
             && ! string_is_empty($domain)
             && is_domain($domain)
           );

    return { message => qq{"$p->{email_address}" is not a valid email address.},
             field   => 'email_address',
           };
}

sub _PrimaryAddressSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('Address') )
           ->from( $schema->table('Address') )
           ->where( $schema->table('Address')->column('contact_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $schema->table('Address')->column('is_primary'),
                  '=', Fey::Literal::String->new('t') )
           ->limit(1);

    return $select;
}

sub _PrimaryPhoneNumberSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('PhoneNumber') )
           ->from( $schema->table('PhoneNumber') )
           ->where( $schema->table('PhoneNumber')->column('contact_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $schema->table('PhoneNumber')->column('is_primary'),
                  '=', Fey::Literal::String->new('t') )
           ->limit(1);

    return $select;
}

sub _canonicalize_website
{
    my $self = shift;
    my $p    = shift;

    return if string_is_empty( $p->{website} );

    my $website =
        $p->{website} =~ /^https?/
        ? $p->{website}
        : 'http://' . $p->{website};

    my $uri = URI->new($website);

    if ( ( $uri->scheme() && $uri->scheme() !~ /^https?/ )
         || string_is_empty( $uri->host() ) )
    {
        $p->{website} = undef;
        return;
    }

    $p->{website} = $uri->canonical() . '';

    return;
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
