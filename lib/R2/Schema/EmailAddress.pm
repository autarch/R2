package R2::Schema::EmailAddress;

use strict;
use warnings;
use namespace::autoclean;

use Data::Validate::Domain qw( is_domain );
use R2::Schema;
use R2::Schema::Contact;
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator' =>
    { steps => [qw( _valid_email_address )] };
with 'R2::Role::Schema::HistoryRecorder';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('EmailAddress') );

    has_one( $schema->table('Contact') );
}

sub _valid_email_address {
    my $self = shift;
    my $p    = shift;

    return if string_is_empty( $p->{email_address} );

    my ( $name, $domain ) = split /\@/, $p->{email_address};

    return
        if ( !string_is_empty($name)
        && $name =~ /^[^@]+$/
        && !string_is_empty($domain)
        && is_domain($domain) );

    return {
        message => qq{"$p->{email_address}" is not a valid email address.},
        field   => 'email_address',
    };
}

sub summary { $_[0]->email_address() }

__PACKAGE__->meta()->make_immutable();

1;

__END__
