package R2::View::Mason;

use strict;
use warnings;

use base 'Catalyst::View::Mason';

{

    package R2::Mason::Web;

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
{
    my $config = R2::Config->instance();

    my %config = (
        comp_root => $config->share_dir()->subdir('mason')->stringify(),
        data_dir =>
            $config->cache_dir()->subdir( 'mason', 'web' )->stringify(),
        error_mode           => 'fatal',
        in_package           => 'R2::Mason::Web',
        use_match            => 0,
        default_escape_flags => 'h',
                 );

    if ( $config->is_production() ) {
        $config{static_source} = 1;
        $config{static_source_touch_file}
            = $config->etc_dir()->file('mason-touch')->stringify();
    }

    __PACKAGE__->config( \%config );
}

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
