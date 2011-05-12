use strict;
use warnings;

use Test::More;

use HTML::DOM;
use List::AllUtils qw( any );
use List::AllUtils qw( first );
use R2::Web::FormMunger;
use R2::Web::FormData;

{

    package Test::Form;

    use Moose;
    use Chloro;
    use Moose::Util::TypeConstraints;

    subtype 'NoFoo', as 'Str', where { $_ !~ /FOO/ };

    field text1 => ( isa => 'NoFoo' );

    field text2 => ( isa => 'Str' );

    field select1 => ( isa => 'Str' );

    field select2 => ( isa => 'ArrayRef[Str]' );

    field textarea => ( isa => 'ArrayRef[Str]' );

    field nested => ( isa => 'NoFoo' );

    sub _validate_form {
        my $self   = shift;
        my $params = shift;

        return unless exists $params->{bad_form};

        return 'This form has an error.';
    }

    __PACKAGE__->meta()->make_immutable();
}

my $html = <<'EOF';
<form action="/" method="POST">
 <input type="hidden" name="hidden" value="1" />

 <div class="form-item">
  <label for="text1">Text 1:</label>
  <input type="text" name="text1" id="text1" value="" />
 </div>

 <div class="form-item">
  <label for="text2">Text 2:</label>
  <input type="text" name="text2" id="text2" value="could be overwritten" />
 </div>

 <div class="form-item">
  <label for="select1">Select 1:</label>
  <select name="select1">
   <option value="1">1</option>
   <option value="2">2</option>
   <option value="3">3</option>
   <option value="4">4</option>
  </select>
 </div>

 <div class="form-item">
  <label for="select2">Select 2:</label>
  <select multiple="1" name="select2">
   <option value="1">1</option>
   <option value="2">2</option>
   <option value="3">3</option>
   <option value="4">4</option>
  </select>
 </div>

 <!--__SELECT__-->

 <div class="form-item">
  <label for="textarea">Textarea:</label>
  <textarea name="textarea" id="textarea"></textarea>
 </div>

 <div class="form-item">
  <label for="nested">Nested:</label>
  <div class="foo">
   <input type="text" name="nested" id="nested" />
  </div>
 </div>
</form>
EOF

my $form = Test::Form->new();

{
    my $form_dom = form_elt_for();

    like(
        $form_dom->as_HTML(), qr{<form.+</form>}xism,
        'still returns form if there is nothing to alter'
    );

    local $TODO
        = 'I cannot figure out how to make HTML::DOM (or TreeBuilder?) leave my tag endings in place';
    like(
        $form_dom->innerHTML(), qr{<input [^>]+/>},
        'input tag still ends with />'
    );
}

{
    my $form_dom = form_elt_for(
        resultset => $form->process( params => { bad_form => 1 } ),
    );

    generic_error_div_tests($form_dom);
}

{
    my $form_dom = form_elt_for(
        resultset => $form->process( params => { bad_form => 1 } ),
    );

    generic_error_div_tests($form_dom);
}

{
    my $form_dom = form_elt_for(
        resultset => $form->process( params => { text1 => 'FOO' } ),
    );

    text1_error_div_tests($form_dom);
}

{
    my $form_dom = form_elt_for(
        resultset => $form->process(
            params => {
                bad_form => 1,
                text1    => 'FOO',
            }
        ),
    );

    generic_error_div_tests($form_dom);
    text1_error_div_tests($form_dom);
}

{
    my $data = R2::Web::FormData->new(
        sources => [
            {
                text1    => 't1',
                text2    => 't2',
                select1  => 1,
                select2  => [ 2, 3 ],
                textarea => 'tarea',
            },
        ],
    );

    my $form_dom = form_elt_for( form_data => $data );

    fill_in_form_tests($form_dom);
}

{
    my $data = R2::Web::FormData->new(
        sources => [
            {
                text1    => 't1',
                text2    => 't2',
                select1  => 1,
                select2  => [ 2, 3 ],
                textarea => 'tarea',
            },
        ],
    );

    my $resultset = $form->process(
        params => {
            text1    => 'FOO',
            text2    => 't2',
            select1  => 1,
            select2  => [ 2, 3 ],
            textarea => 'tarea',
            bad_form => 1,
        },
    );

    my $form_dom = form_elt_for(
        resultset => $resultset,
        form_data => $data,
    );

    generic_error_div_tests($form_dom);
    text1_error_div_tests($form_dom);
    fill_in_form_tests($form_dom);
}

{
    my $form_dom = form_elt_for(
        resultset => $form->process(
            params => {
                nested => 'FOO',
            }
        ),
    );

    my $nested = first { $_->getAttribute('name') eq 'nested' }
    $form_dom->getElementsByTagName('input');

    my $grandparent = $nested->parentNode()->parentNode();

    my $error_p = ( $grandparent->getElementsByTagName('p') )[0];

    is(
        $error_p->className(), 'error-message',
        q{found error message p tag}
    );
    is(
        $error_p->parentNode(), $grandparent,
        q{error message is a child of nested input's grandparent node}
    );
}

{
    my $select = <<'EOF';
 <div class="form-item">
  <label for="select3">Select 3:</label>
  <select name="select3">
   <option value="99">ninety-nine</option>
  </select>
 </div>
EOF

    $html =~ s/\Q<!--__SELECT__-->/$select/;

    my $form_dom = form_elt_for();

    my $select3 = first { $_->getAttribute('name') eq 'select3' }
    $form_dom->getElementsByTagName('input');

    is(
        lc $select3->tagName(), 'input',
        'select3 has been made an input element'
    );
    is(
        $select3->getAttribute('type'), 'hidden',
        'select3 is a hidden input element'
    );
    is(
        $select3->getAttribute('value'), '99',
        'select3 value is 99'
    );

    my $span = first { $_->className() eq 'text-for-hidden' }
    $form_dom->getElementsByTagName('div');

    is(
        $span->firstChild()->data(), 'ninety-nine',
        'option text is now in a div'
    );
}

sub form_elt_for {
    my $form_dom = R2::Web::FormMunger->new(
        html => $html,
        @_,
    );

    my $dom = HTML::DOM->new();
    $dom->write( $form_dom->filled_in_form() );

    return $dom->getElementsByTagName('form')->[0];
}

sub generic_error_div_tests {
    my $form_dom = shift;

    my $error_div = first {
        $_->can('tagName')
            && lc $_->tagName() eq 'div'
            && $_->className eq 'form-error';
    }
    $form_dom->childNodes();

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok( $error_div, 'form has an error div as a child node' );

    my $error_p = ( $error_div->getElementsByTagName('p') )[0];

    ok( $error_p, 'error div has a P element as a child' );
    is(
        $error_p->firstChild()->firstChild()->data(),
        'This form has an error.',
        'text of p is expected error message'
    );
}

sub text1_error_div_tests {
    my $form_dom = shift;

    my $error_div = first {
        $_->can('tagName')
            && lc $_->tagName() eq 'div'
            && $_->className eq 'form-item error';
    }
    $form_dom->childNodes();

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok(
        $error_div,
        'form does have a form-item div with an additional error class'
    );

    my $error_p = ( $error_div->getElementsByTagName('p') )[0];

    ok( $error_p, 'error div has a P element as a child' );
    is(
        $error_p->firstChild()->firstChild()->data(),
        'The text1 field did not contain a valid value.',
        'text of p is expected error message'
    );
}

sub fill_in_form_tests {
    my $form_dom = shift;

    my $text1 = first { $_->name() eq 'text1' }
    $form_dom->getElementsByTagName('input');

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is(
        $text1->value(), 't1',
        'text1 has expected value'
    );

    my $text2 = first { $_->name() eq 'text2' }
    $form_dom->getElementsByTagName('input');

    is(
        $text2->value(), 't2',
        'text1 has expected value'
    );

    my $select1 = first { $_->name() eq 'select1' }
    $form_dom->getElementsByTagName('select');

    is_deeply(
        [
            map  { $_->value() }
            grep { $_->selected() } $select1->options()
        ],
        [1],
        'select1 has expected option marked as selected'
    );

    my $select2 = first { $_->name() eq 'select2' }
    $form_dom->getElementsByTagName('select');

    is_deeply(
        [
            map  { $_->value() }
            grep { $_->selected() } $select2->options()
        ],
        [ 2, 3 ],
        'select2 has expected options marked as selected'
    );

    my $textarea = first { $_->name() eq 'textarea' }
    $form_dom->getElementsByTagName('textarea');

    my $textarea_text = $textarea->firstChild()->data();
    $textarea_text =~ s/^\s+|\s+$//g;

    is(
        $textarea_text, 'tarea',
        'textarea has expected text content'
    );
}

done_testing();
