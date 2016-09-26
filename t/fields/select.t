use strict;
use warnings;
use Test::More;
use Data::MuForm::Field::Text;


{
   package Test::Form;
   use Moo;
   use Data::MuForm::Meta;
   extends 'Data::MuForm';

   has '+name' => ( default => 'options_form' );
   has_field 'test_field' => (
               type => 'Text',
               label => 'TEST',
               id    => 'f99',
            );
   has_field 'fruit' => ( type => 'Select' );
   has_field 'vegetables' => ( type => 'Multiple' );
   has_field 'empty' => ( type => 'Multiple', no_option_validation => 1 );
   has_field 'build_attr' => ( type => 'Select' );

   sub default_fruit { 2 }

   # the following sometimes happens with db options
   sub options_empty { ([]) }

   has 'options_fruit' => ( is => 'rw',
       default => sub { [1 => 'apples', 2 => 'oranges', 3 => 'kiwi'] } );

   sub options_vegetables {
       return (
           1   => 'lettuce',
           2   => 'broccoli',
           3   => 'carrots',
           4   => 'peas',
       );
   }

=comment
   has 'options_build_attr' => ( is => 'ro', traits => ['Array'], lazy_build => 1 );
   sub _build_options_build_attr {
       return [
           1 => 'testing',
           2 => 'moose',
           3 => 'attr builder',
       ];
   }
=cut
}


my $form = Test::Form->new;
ok( $form, 'create form');

my $veg_options =   [ {'label' => 'lettuce',
      'value' => 1 },
     {'label' => 'broccoli',
      'value' => 2 },
     {'label' => 'carrots',
      'value' => 3 },
     {'label' => 'peas',
      'value' => 4 } ];
my $field_options = $form->field('vegetables')->options;
is_deeply( $field_options, $veg_options,
   'get options for vegetables' );

my $fruit_options = [ {'label' => 'apples',
       'value' => 1 },
      {'label' => 'oranges',
       'value' => 2 },
      {'label' => 'kiwi',
       'value' => 3 } ];
$field_options = $form->field('fruit')->options;
is_deeply( $field_options, $fruit_options,
    'get options for fruit' );

=comment
my $build_attr_options = [ {'label' => 'testing',
       'value' => 1 },
      {'label' => 'moose',
       'value' => 2 },
      {'label' => 'attr builder',
       'value' => 3 } ];
$field_options = $form->field('build_attr')->options;
is_deeply( $field_options, $build_attr_options,
    'get options for build_attr' );
=cut

is( $form->field('fruit')->value, 2, 'initial value ok');

$form->process( params => {},
    init_object => { vegetables => undef, fruit => undef, build_attr => undef } );
$field_options = $form->field('vegetables')->options;
is_deeply( $field_options, $veg_options,
   'get options for vegetables after process' );
$field_options = $form->field('fruit')->options;
is_deeply( $field_options, $fruit_options,
    'get options for fruit after process' );
=comment
$field_options = $form->field('build_attr')->options;
is_deeply( $field_options, $build_attr_options,
    'get options for fruit after process' );
=cut

my $params = {
   fruit => 2,
   vegetables => [2,4],
   empty => 'test',
};
$DB::single=1;
$form->process( $params );
ok( $form->validated, 'form validated' );
is( $form->field('fruit')->value, 2, 'fruit value is correct');
is_deeply( $form->field('vegetables')->value, [2,4], 'vegetables value is correct');

is_deeply( $form->fif, { fruit => 2, vegetables => [2, 4], empty => ['test'], test_field => '', build_attr => '' },
    'fif is correct');
#is_deeply( $form->values, { fruit => 2, vegetables => [2, 4], empty => ['test'], build_attr => undef },
is_deeply( $form->values, { fruit => 2, vegetables => [2, 4], empty => ['test'] },
    'values are correct');

=comment
is( $form->field('vegetables')->as_label, 'broccoli, peas', 'multiple as_label works');
is( $form->field('vegetables')->as_label([3,4]), 'carrots, peas', 'pass in multiple as_label works');

$params = {
    fruit => 2,
    vegetables => 4,
};
$form->process($params);
is_deeply( $form->field('vegetables')->value, [4], 'value for vegetables correct' );
is_deeply( $form->field('vegetables')->fif, [4], 'fif for vegetables correct' );


{
    package Test::Multiple::InitObject;
    use Moo;
    use Data::MuForm::Meta;
    extends 'Data::MuForm';

    has_field 'foo' => ( default => 'my_foo' );
    has_field 'bar' => ( type => 'Multiple' );

   sub options_bar {
       return (
           1   => 'one',
           2   => 'two',
           3   => 'three',
           4   => 'four',
       );
   }


}

$form = Test::Multiple::InitObject->new;
my $init_object = { foo => 'new_foo', bar => [3,4] };
$form->process(init_object => $init_object, params => {} );
my $rendered = $form->render;
like($rendered, qr/<option value="4" id="bar.1" selected="selected">four<\/option>/, 'rendered option');
my $value = $form->value;
is_deeply( $value, $init_object, 'correct value');
=cut

done_testing;
