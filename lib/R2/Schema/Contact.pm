package R2::Schema::Contact;

use strict;
use warnings;

use Fey::Literal::String;
use Fey::Placeholder;
use R2::Image;
use R2::Schema;
use R2::Schema::Address;
use R2::Schema::EmailAddress;
use R2::Schema::File;
use R2::Schema::PhoneNumber;
use R2::Schema::Website;
use R2::Util qw( string_is_empty );

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

    has_many 'email_addresses' =>
        ( table    => $schema->table('EmailAddress'),
          order_by => [ $schema->table('EmailAddress')->column('is_preferred'),
                        'DESC',
                        $schema->table('EmailAddress')->column('email_address'),
                        'ASC',
                      ],
          cache    => 1,
        );

    has_one 'preferred_email_address' =>
        ( table       => $schema->table('EmailAddress'),
          select      => __PACKAGE__->_PreferredEmailAddressSelect(),
          bind_params => sub { $_[0]->contact_id() }
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

    has_one 'preferred_address' =>
        ( table       => $schema->table('Address'),
          select      => __PACKAGE__->_PreferredAddressSelect(),
          bind_params => sub { $_[0]->contact_id() }
        );

    has_many 'phone_numbers' =>
        ( table => $schema->table('PhoneNumber'),
          cache => 1,
        );

    has_one 'preferred_phone_number' =>
        ( table       => $schema->table('PhoneNumber'),
          select      => __PACKAGE__->_PreferredPhoneNumberSelect(),
          bind_params => sub { $_[0]->contact_id() }
        );

    has_many 'websites' =>
        ( table    => $schema->table('Website'),
          order_by => [ $schema->table('Website')->column('label'),
                        'ASC',
                        $schema->table('Website')->column('uri'),
                        'ASC',
                      ],
          cache    => 1,
        );
}

sub _PreferredEmailAddressSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('EmailAddress') )
           ->from( $schema->table('EmailAddress') )
           ->where( $schema->table('EmailAddress')->column('contact_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $schema->table('Address')->column('is_preferred'),
                  '=', Fey::Literal::String->new('t') )
           ->limit(1);

    return $select;
}

sub _PreferredAddressSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('Address') )
           ->from( $schema->table('Address') )
           ->where( $schema->table('Address')->column('contact_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $schema->table('Address')->column('is_preferred'),
                  '=', Fey::Literal::String->new('t') )
           ->limit(1);

    return $select;
}

sub _PreferredPhoneNumberSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('PhoneNumber') )
           ->from( $schema->table('PhoneNumber') )
           ->where( $schema->table('PhoneNumber')->column('contact_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $schema->table('PhoneNumber')->column('is_preferred'),
                  '=', Fey::Literal::String->new('t') )
           ->limit(1);

    return $select;
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
