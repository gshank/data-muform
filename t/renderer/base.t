use strict;
use warnings;
use Test::More;
use Data::MuForm::Test;

use_ok('Data::MuForm::Renderer::Standard');

{
    package MyApp::Form::Test;
    use Moo;
    use Data::MuForm::Meta;
    extends 'Data::MuForm';

    has_field 'foo' => ( required => 1, maxlength => 10 );
    has_field 'bar' => (
        type => 'Select',
        empty_select => '-- Choose --',
        options => [
            1 => 'one',
            2 => 'two',
        ],
    );
    has_field 'jax' => ( type => 'Checkbox', checkbox_value => 'yes' );
    has_field 'sol' => ( type => 'Textarea', cols => 50, rows => 3 );

    has_field 'submitted' => ( type => 'Submit', value => 'Save' );
}

my $form = MyApp::Form::Test->new;
ok( $form, 'form built' );

# text field
my $rendered = $form->field('foo')->render_element({ placeholder => 'Type...', class => 'mb10 x322' });
my $expected = q{
  <input type="text" id="foo" name="foo" class="mb10 x322" placeholder="Type..." maxlength="10" value="">
};
is_html( $rendered, $expected, 'got expected output for text element');

$form->process( params => { foo => '', bar => 1, sol => 'Some text' } );

# text field
$rendered = $form->field('foo')->render_element({ class => 'bm10 x333' });
$expected = q{
  <input type="text" id="foo" name="foo" class="bm10 x333 error" maxlength="10" value="">
};
is_html( $rendered, $expected, 'got expected output for text element with error');

# select field
$rendered = $form->field('bar')->render_element({ class => 'select 666' });
$expected = q{
  <select id="bar" name="bar" class="select 666">
    <option value="">-- Choose --</option>
    <option value="1">one</option>
    <option value="2">two</option>
  </select>
};
is_html( $rendered, $expected, 'got expected output for select element' );

# checkbox field
$rendered = $form->field('jax')->render_element({ class => 'hhh yyy' });
$expected = q{
  <checkbox id="jax" name="jax" value="yes" class="hhh yyy">
};
is_html( $rendered, $expected, 'got expected output for checkbox element' );


# textarea field
$rendered = $form->field('sol')->render_element({ class => 'the end' });
$expected = q{
  <textarea id="sol" name="sol" class="the end" cols="50" rows="3">Some text</textarea>
};
is_html( $rendered, $expected, 'got expected output for textarea element' );

# submit field
$rendered = $form->field('submitted')->render_element({ class => ['h23', 'bye' ] });
$expected = q{
  <input type="submit" name="submitted" id="submitted" class="h23 bye" value="Save">
};
is_html( $rendered, $expected, 'got expected output for submit element' );

done_testing;
