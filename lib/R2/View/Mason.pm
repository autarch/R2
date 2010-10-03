package R2::View::Mason;

use strict;
use warnings;

use base 'Catalyst::View::Mason';

{

    package R2::Mason;

    use Lingua::EN::Inflect qw( PL_N );
    use R2::Util qw( string_is_empty english_list );
    use R2::URI qw( static_uri );
    use R2::Web::Util qw( format_note );
}

# used in templates
use HTML::FillInForm;
use Path::Class;
use R2::Config;
use R2::Web::Form;
use R2::Web::FormData;
use R2::Util qw( string_is_empty );

__PACKAGE__->config( R2::Config->new()->mason_config() );

# sub new
# {
#     my $class = shift;

#     my $self = $class->SUPER::new(@_);

# #    R2::Util::chown_files_for_server( $self->template()->files_written() );

#     return $self;
# }

sub has_template_for_path {
    my $self = shift;
    my $path = shift;

    return -f file(
        $self->config()->{comp_root},
        ( grep { !string_is_empty($_) } split /\//, $path ),
    );
}

1;

__END__

=head1 NAME

R2::View::Mason - Catalyst View

=head1 SYNOPSIS

See L<R2>

=head1 DESCRIPTION

Catalyst View.

=head1 AUTHOR

Dave Rolsky,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
