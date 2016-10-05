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

    has_field 'foo';
    has_field 'bar';

}

my $form = MyApp::Form::Test->new;
ok( $form );

my $rendered = $form->field('foo')->render_element({ placeholder => 'Type...', class => 'mb10 x322' });
my $expected = q{
  <input type="text" id="foo" name="foo" class="mb10 x322" placeholder="Type..." value="">
};
is_html( $rendered, $expected, 'got expected output for text element');

done_testing;
