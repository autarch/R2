package R2::Web::FormMunger;

use strict;
use warnings;
use namespace::autoclean;

use HTML::DOM;
use HTML::FillInForm;
use R2::Config;
use R2::Types qw( ArrayRef Bool ChloroError HashRef Str );
use R2::Web::FormData;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has 'html' => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has 'exclude' => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    default => sub { [] },
);

has '_dom' => (
    is      => 'rw',
    isa     => 'HTML::DOM',
    lazy    => 1,
    default => sub {
        my $dom = HTML::DOM->new();
        $dom->write( $_[0]->html() );
        return $dom;
    },
);

has resultset => (
    is        => 'ro',
    isa       => 'Chloro::ResultSet',
    predicate => '_has_resultset',
);

has 'errors' => (
    is      => 'ro',
    isa     => ArrayRef [ ChloroError | HashRef | Str ],
    default => sub { [] },
);

has 'form_data' => (
    is        => 'ro',
    isa       => 'R2::Web::FormData',
    predicate => '_has_form_data',
);

has 'filled_in_form' => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_fill_in_form',
);

has 'make_pretty' => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has 'is_fragment' => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

sub _fill_in_form {
    my $self = shift;

    $self->_fill_errors() unless $self->is_fragment();

    $self->_fill_form_data();

    $self->_collapse_single_option_selects();

    my $html = $self->_form_html_from_dom();

    return $html;
}

sub _fill_errors {
    my $self = shift;

    if ( $self->_has_resultset() ) {
        $self->_handle_resultset();
    }
    else {
        $self->_handle_old_style_errors();
    }
}

sub  _handle_resultset {
    my $self = shift;

    my $form = $self->_dom()->getElementsByTagName('form')->[0];
    return unless $form;

    return if $self->resultset()->is_valid();

    my @errors = map { $self->_errors_for_result($_) }
        $self->resultset()->all_errors();

    $self->_apply_errors_to_form( $form, \@errors );
}

sub _errors_for_result {
    my $self  = shift;
    my $error = shift;

    if ( $error->can('field')
        && defined $error->result()->param_names()->[0] ) {

        return {
            field => $error->result()->param_names()->[0],
            text  => $error->message()->text(),
        };
    }
    else {
        return {
            text => $error->message()->text(),
        };
    }
}

sub _apply_errors_to_form {
    my $self   = shift;
    my $form   = shift;
    my $errors = shift;

    my $error_div = $self->_dom()->createElement('div');
    $error_div->className('form-error');

    for my $error ( @{$errors} ) {
        my $field;
        my $message;

        if ( defined $error->{field} ) {
            if ( my $div = $self->_get_div_for_field( $error->{field} ) ) {

                $div->className( $div->className() . ' error' );

                my $p = $self->_create_error_para( $error->{text} );
                $div->insertBefore( $p, $div->firstChild() );
            }
        }

        my $p = $self->_create_error_para( $error->{text} );

        $error_div->appendChild($p);
    }

    $form->insertBefore( $error_div, $form->firstChild() );

    return;
}

sub  _handle_old_style_errors {
    my $self = shift;

    my $errors = $self->errors();
    return unless @{$errors};

    my $form = $self->_dom()->getElementsByTagName('form')->[0];
    return unless $form;

    my $error_div = $self->_dom()->createElement('div');
    $error_div->className('form-error');

    for my $error ( @{$errors} ) {
        my $field;
        my $message;

        if ( ref $error && $error->{field} ) {
            $field = $error->{field};
            $message = $error->{message} || $error->{text};
        }
        else {
            $message
                = ref $error
                ? ( $error->{message} || $error->{text} )
                : $error;
        }

        if ( defined $field ) {
            if ( my $div = $self->_get_div_for_field($field) ) {

                $div->className( $div->className() . ' error' );

                my $p = $self->_create_error_para($message);
                $div->insertBefore( $p, $div->firstChild() );
            }
        }

        my $p = $self->_create_error_para($message);

        $error_div->appendChild($p);
    }

    $form->insertBefore( $error_div, $form->firstChild() );

    return;
}

sub _get_div_for_field {
    my $self = shift;
    my $id   = shift;

    my $elt = $self->_dom()->getElementById($id);

    return unless $elt;

    my $node = $elt;

    while ( $node = $node->parentNode() ) {
        return $node
            if lc $node->tagName() eq 'div'
                && $node->className() =~ /form-item/;

        last if lc $node->tagName() eq 'form';
    }
}

sub _create_error_para {
    my $self = shift;
    my $text = shift;

    # The extra span is for the benefit of CSS, so we can set the left margin
    # of the paragraph
    my $span = $self->_dom()->createElement('span');
    $span->appendChild( $self->_dom()->createTextNode($text) );

    my $p = $self->_dom()->createElement('p');
    $p->className('error-message');
    $p->appendChild($span);

    return $p;
}

sub _fill_form_data {
    my $self = shift;

    return unless $self->_has_form_data();

    my $html = $self->_form_html_from_dom();

    my $filled = HTML::FillInForm->fill(
        \$html,
        $self->form_data(),
        ignore_fields => $self->exclude(),
    );

    my $dom = HTML::DOM->new();
    $dom->write($filled);

    $self->_set_dom($dom);
}

sub _collapse_single_option_selects {
    my $self = shift;

    my @to_collapse;
    for my $select ( @{ $self->_dom()->getElementsByTagName('select') } ) {
        next if $select->id() =~ /^wpms-/;

        my @options = $select->options();

        next if @options != 1;

        push @to_collapse, [ $select, $options[0] ];
    }

    # Modifying the dom as we loop through it seems to cause weirdness
    # where some select elements get skipped.
    $self->_collapse_single_option_select( @{$_} ) for @to_collapse;
}

sub _collapse_single_option_select {
    my $self   = shift;
    my $select = shift;
    my $option = shift;

    my $div = $self->_dom()->createElement('div');
    $div->className('text-for-hidden');
    $div->appendChild($_) for @{ $option->childNodes() };

    my $hidden = $self->_dom()->createElement('input');
    $hidden->setAttribute( type  => 'hidden' );
    $hidden->setAttribute( name  => $select->getAttribute('name') );
    $hidden->setAttribute( value => $option->getAttribute('value') );

    my $parent = $select->parentNode();

    $parent->replaceChild( $div, $select );
    $parent->appendChild($hidden);
}

sub _form_html_from_dom {
    my $self = shift;

    if ( $self->is_fragment() ) {
        return $self->_dom()->getElementsByTagName('body')->[0]->innerHTML();
    }
    else {
        return $self->_dom()->getElementsByTagName('form')->[0]->parentNode()
            ->innerHTML();
    }
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Does post-processing on HTML forms
