package R2::View::Mason;

use strict;
use warnings;

use Moose;

extends 'Catalyst::View::HTML::Mason';

{

    package R2::Mason::Web;

    use Lingua::EN::Inflect qw( PL_N );
    use List::AllUtils qw( any );
    use R2::Util qw( english_list new_uuid string_is_empty );
    use R2::URI qw( static_uri );
    use R2::Web::Util qw( format_note );
    use Number::Format qw( format_price );

    sub format_money {
        return format_price( shift, 2, '$' );
    }

    sub POSS {
        my $noun = shift;

        return $noun . q{'s};
    }
}

# used in templates
use HTML::FillInForm;
use Path::Class;
use R2::Config;
use R2::Web::FormData;
use R2::Web::FormMunger;
use R2::Util qw( string_is_empty );
{
    my $config = R2::Config->instance();

    my %config = (
        comp_root => $config->share_dir()->subdir('mason')->stringify(),
        data_dir =>
            $config->cache_dir()->subdir( 'mason', 'web' )->stringify(),
        error_mode           => 'fatal',
        in_package           => 'R2::Mason::Web',
        default_escape_flags => 'h',
        allow_globals        => ['$c'],
    );

    if ( $config->is_production() ) {
        $config{static_source} = 1;
        $config{static_source_touch_file}
            = $config->etc_dir()->file('mason-touch')->stringify();
    }

    __PACKAGE__->config( interp_args => \%config );
}

around render => sub {
    my $orig = shift;
    my $self = shift;

    local $R2::Mason::Web::c = $_[0];

    return $self->$orig(@_);
};

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
