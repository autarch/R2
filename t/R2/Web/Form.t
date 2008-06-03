use strict;
use warnings;

use Test::More tests => 37;

use HTML::DOM;
use List::MoreUtils qw( any );
use List::Util qw( first );
use R2::Web::Form;
use R2::Web::FormData;


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
</form>
EOF

{
    my $form = form_elt_for();

    like( $form->as_HTML(), qr{<form.+</form>}xism,
          'still returns form if there is nothing to alter' );
}

{
    my $form = form_elt_for( errors => [ { message => 'A generic error' } ],
                           );

    generic_error_div_tests($form);
}

{
    my $form = form_elt_for( errors => [ 'A generic error' ],
                           );

    generic_error_div_tests($form);
}

{
    my $form = form_elt_for( errors => [ { field   => 'text1',
                                           message => 'Error in text1' } ],
                           );

    ok( ( ! any { $_->can('tagName')
                  && lc $_->tagName() eq 'div'
                  && $_->className eq 'form-error' } $form->childNodes() ),
        'form does not have a generic error div' );

    text1_error_div_tests($form);
}


{
    my $form = form_elt_for( errors => [ { message => 'A generic error',
                                         },
                                         { field   => 'text1',
                                           message => 'Error in text1' },
                                       ],
                           );

    generic_error_div_tests($form);
    text1_error_div_tests($form);
}

{
    my $data = R2::Web::FormData->new( { text1    => 't1',
                                         text2    => 't2',
                                         select1  => 1,
                                         select2  => [ 2, 3 ],
                                         textarea => 'tarea',
                                       },
                                     );

    my $form = form_elt_for( form_data => $data );

    fill_in_form_tests($form);
}

{
    my $data = R2::Web::FormData->new( { text1    => 't1',
                                         text2    => 't2',
                                         select1  => 1,
                                         select2  => [ 2, 3 ],
                                         textarea => 'tarea',
                                       },
                                     );

    my $form = form_elt_for( errors    => [ { message => 'A generic error',
                                            },
                                            { field   => 'text1',
                                              message => 'Error in text1' },
                                          ],
                             form_data => $data,
                           );

    generic_error_div_tests($form);
    text1_error_div_tests($form);
    fill_in_form_tests($form);
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

    my $form = form_elt_for();

    my $select3 =
        first { $_->getAttribute('name') eq 'select3' } @{ $form->getElementsByTagName('input') };

    is( lc $select3->tagName(), 'input',
        'select3 has been made an input element' );
    is( $select3->getAttribute('type'), 'hidden',
        'select3 is a hidden input element' );
    is( $select3->getAttribute('value'), '99',
        'select3 value is 99' );

    my $div =
        first { $_->className() eq 'text-for-hidden' } @{ $form->getElementsByTagName('div') };

    is( $div->firstChild()->data(), 'ninety-nine',
        'option text is now in a div' );
}

sub form_elt_for
{
    my $form = R2::Web::Form->new( html => $html,
                                   @_,
                                 );

    my $dom = HTML::DOM->new();
    $dom->write( $form->filled_in_form() );

    return $dom->getElementsByTagName('form')->[0];
}

sub generic_error_div_tests
{
    my $form = shift;

    my $error_div =
        first { $_->can('tagName')
                && lc $_->tagName() eq 'div'
                && $_->className eq 'form-error' } $form->childNodes();

    ok( $error_div, 'form has an error div as a child node' );

    my $error_p = $error_div->getElementsByTagName('p')->[0];

    ok( $error_p, 'error div has a P element as a child' );
    is( $error_p->firstChild()->firstChild()->data(),
        'A generic error',
        'text of p is expected error message' );
}

sub text1_error_div_tests
{
    my $form = shift;

    my $error_div =
        first { $_->can('tagName')
                && lc $_->tagName() eq 'div'
                && $_->className eq 'form-item error' } $form->childNodes();

    ok( $error_div, 'form does have a form-item div with an additional error class' );

    my $error_p = $error_div->getElementsByTagName('p')->[0];

    ok( $error_p, 'error div has a P element as a child' );
    is( $error_p->firstChild()->firstChild()->data(),
        'Error in text1',
        'text of p is expected error message' );
}

sub fill_in_form_tests
{
    my $form = shift;

    my $text1 =
        first { $_->name() eq 'text1' } $form->getElementsByTagName('input');

    is( $text1->value(), 't1',
        'text1 has expected value' );

    my $text2 =
        first { $_->name() eq 'text2' } $form->getElementsByTagName('input');

    is( $text2->value(), 't2',
        'text1 has expected value' );

    my $select1 =
        first { $_->name() eq 'select1' } $form->getElementsByTagName('select');

    is_deeply( [ map { $_->value() }
                 grep { $_->selected() }
                 $select1->options()
               ],
               [ 1 ],
               'select1 has expected option marked as selected'
             );

    my $select2 =
        first { $_->name() eq 'select2' } $form->getElementsByTagName('select');

    is_deeply( [ map { $_->value() }
                 grep { $_->selected() }
                 $select2->options()
               ],
               [ 2, 3 ],
               'select2 has expected options marked as selected'
             );

    my $textarea =
        first { $_->name() eq 'textarea' } $form->getElementsByTagName('textarea');

    my $textarea_text = $textarea->firstChild()->data();
    $textarea_text =~ s/^\s+|\s+$//g;

    is( $textarea_text, 'tarea',
        'textarea has expected text content' );
}
