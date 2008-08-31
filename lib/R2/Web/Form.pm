package R2::Web::Form;

use strict;
use warnings;

use HTML::DOM;
use HTML::FillInForm;
use R2::Config;
use R2::Web::FormData;

use Moose;
use MooseX::SemiAffordanceAccessor;

has 'html' =>
    ( is       => 'ro',
      isa      => 'Str',
      required => 1,
    );

has '_dom' =>
    ( is      => 'rw',
      isa     => 'HTML::DOM',
      lazy    => 1,
      default => sub { my $dom = HTML::DOM->new();
                       $dom->write( $_[0]->html() );
                       return $dom },
    );

has 'errors' =>
    ( is      => 'ro',
      isa     => 'ArrayRef[HashRef|Str]',
      default => sub { [] },
    );

has 'form_data' =>
    ( is      => 'ro',
      isa     => 'R2::Web::FormData',
      default => sub { R2::Web::FormData->new() },
    );

has 'filled_in_form' =>
    ( is      => 'ro',
      isa     => 'Str',
      lazy    => 1,
      builder => '_fill_in_form',
    );

has 'make_pretty' =>
    ( is      => 'ro',
      isa     => 'Bool',
      default => 0,
    );

sub _fill_in_form
{
    my $self = shift;

    $self->_fill_errors();

    $self->_fill_form_data();

    $self->_collapse_single_option_selects();

    my $html = $self->_form_html_from_dom();

    return $html unless $self->make_pretty();

    require HTML::Tidy;
    my $tidy = HTML::Tidy->new( { indent         => 'auto',
                                  output_xhtml   => 1,
                                  doctype        => 'omit',
                                  show_body_only => 1,
                                } );

    $tidy->ignore( type => HTML::Tidy::TIDY_WARNING() );
    $tidy->ignore( type => HTML::Tidy::TIDY_ERROR() );

    return $tidy->clean($html);
}

sub _fill_errors
{
    my $self = shift;

    my $errors = $self->errors();
    return unless @{ $errors };

    my $error_div = $self->_dom()->createElement('div');
    $error_div->className('form-error');

    for my $error ( @{ $errors } )
    {
        if ( ref $error && $error->{field} )
        {
            my $div = $self->_get_div_for_field( $error->{field} );
            $div->className( $div->className() . ' error' );

            my $p = $self->_create_error_para( $error->{message} );
            $div->insertBefore( $p, $div->firstChild() );
        }
        else
        {
            my $p = $self->_create_error_para( ref $error ? $error->{message} : $error );

            $error_div->appendChild($p);
        }
    }

    my $form = $self->_dom()->getElementsByTagName('form')->[0];
    if ( @{ $error_div->childNodes() } )
    {
        $form->insertBefore( $error_div, $form->firstChild() );
    }
}

sub _get_div_for_field
{
    my $self = shift;
    my $id   = shift;

    my $elt = $self->_dom()->getElementById($id);

    die "No such element: $id\n"
        unless $elt;

    return $elt->parentNode();
}

sub _create_error_para
{
    my $self = shift;
    my $text = shift;

    # The extra span is for the benefit of CSS, so we can set the left margin of the paragraph
    my $span = $self->_dom()->createElement('span');
    $span->appendChild( $self->_dom()->createTextNode($text) );

    my $p = $self->_dom()->createElement('p');
    $p->className('error-message');
    $p->appendChild($span);

    return $p;
}

sub _fill_form_data
{
    my $self = shift;

    my $data = $self->form_data();
    return unless $data->has_sources();

    my $html = $self->_form_html_from_dom();

    my $filled = HTML::FillInForm->fill( \$html, $data );

    my $dom = HTML::DOM->new();
    $dom->write($filled);

    $self->_set_dom($dom);
}

sub _collapse_single_option_selects
{
    my $self = shift;

    for my $select ( @{ $self->_dom()->getElementsByTagName('select') } )
    {
        my @options = $select->options();

        next if @options > 1;

        $self->_collapse_single_option_select( $select, $options[0] );
    }
}

sub _collapse_single_option_select
{
    my $self   = shift;
    my $select = shift;
    my $option = shift;

    my $div = $self->_dom()->createElement('div');
    $div->className('text-for-hidden');
    $div->appendChild($_) for @{ $option->childNodes() };

    my $hidden = $self->_dom()->createElement('input');
    $hidden->setAttribute( type => 'hidden' );
    $hidden->setAttribute( name => $select->getAttribute('name') );
    $hidden->setAttribute( value => $option->getAttribute('value') );

    my $parent = $select->parentNode();

    $parent->removeChild($select);

    $parent->insertBefore( $div, $parent->firstChild() );
    $parent->appendChild($hidden);
}

sub _form_html_from_dom
{
    my $self = shift;

    my $form = $self->_dom()->getElementsByTagName('form')->[0];

    return $form->as_HTML( undef, q{  }, {} );
}

{
    package HTML::DOM::Node;

    no warnings 'redefine';

    sub as_HTML
    {
        (my $clone = shift->clone)->deobjectify_text;
        $clone->SUPER::as_HTML(@_);
    }
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
