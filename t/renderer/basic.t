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
    has_field 'bar';

}

my $form = MyApp::Form::Test->new;
ok( $form, 'form built' );

my $rendered = $form->field('foo')->render_element({ placeholder => 'Type...', class => 'mb10 x322' });
my $expected = q{
  <input type="text" id="foo" name="foo" class="mb10 x322" placeholder="Type..." maxlength="10" value="">
};
is_html( $rendered, $expected, 'got expected output for text element');

$form->process( params => { foo => '', bar => 'somebar' } );
$rendered = $form->field('foo')->render_element({ class => 'bm10 x333' });
$expected = q{
  <input type="text" id="foo" name="foo" class="bm10 x333 error" maxlength="10" value="">
};
is_html( $rendered, $expected, 'got expected output for text element with error');


done_testing;
