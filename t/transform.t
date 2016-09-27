use strict;
use warnings;
use Test::More;

# transform_input_to_value
{
  {
      package MyApp::Form::Test1;
      use Moo;
      use Data::MuForm::Meta;
      extends 'Data::MuForm';

      has_field 'foo' => (
          type => 'Text',
          transform_input_to_value => sub { 'foo transformed' },
      );
      has_field 'bar' => (
          type => 'Text',
          transform_input_to_value => *transform_bar,
      );
      sub transform_bar { 'bar transformed' }

  }

  my $form = MyApp::Form::Test1->new;
  ok( $form );

  my $params = { foo => 'foo', bar => 'bar' };
  $form->process( params => $params );

  is ( $form->field('foo')->value, 'foo transformed', 'foo value was transformed' );
  is ( $form->field('bar')->value, 'bar transformed', 'bar value was transformed' );
}

# transform_param_to_input
{
  {
      package MyApp::Form::Test2;
      use Moo;
      use Data::MuForm::Meta;
      extends 'Data::MuForm';

      has_field 'foo' => (
          type => 'Text',
          transform_param_to_input => sub { 'foo transformed' },
      );
      has_field 'bar' => (
          type => 'Text',
          transform_param_to_input => *transform_bar,
      );
      sub transform_bar { 'bar transformed' }

  }

  my $form = MyApp::Form::Test2->new;
  ok( $form );

  my $params = { foo => 'foo', bar => 'bar' };
  $form->process( params => $params );

  is ( $form->field('foo')->value, 'foo transformed', 'foo value was transformed' );
  is ( $form->field('foo')->fif, 'foo transformed', 'foo fif was transformed' );

  is ( $form->field('bar')->value, 'bar transformed', 'bar value was transformed' );
  is ( $form->field('bar')->fif, 'bar transformed', 'bar fif was transformed' );
}

# transform_default_to_value
{
  {
      package MyApp::Form::Test3;
      use Moo;
      use Data::MuForm::Meta;
      extends 'Data::MuForm';

      has_field 'foo' => (
          type => 'Text',
          transform_default_to_value => sub { 'foo transformed' },
      );
      has_field 'bar' => (
          type => 'Text',
          transform_default_to_value => *transform_bar,
      );
      sub transform_bar { 'bar transformed' }

  }

  my $form = MyApp::Form::Test3->new;
  ok( $form );

  my $params = { foo => 'foo', bar => 'bar' };
  $form->process( params => {}, init_object => { foo => 'foo', bar => 'bar' } );

  is ( $form->field('foo')->value, 'foo transformed', 'foo value was transformed' );
  is ( $form->field('foo')->fif, 'foo transformed', 'foo fif was transformed' );

  is ( $form->field('bar')->value, 'bar transformed', 'bar value was transformed' );
  is ( $form->field('bar')->fif, 'bar transformed', 'bar fif was transformed' );
}

# transform_value_after_validate
{
  {
      package MyApp::Form::Test4;
      use Moo;
      use Data::MuForm::Meta;
      extends 'Data::MuForm';

      has_field 'foo' => (
          type => 'Text',
          transform_value_after_validate => sub { 'foo transformed' },
      );
      has_field 'bar' => (
          type => 'Text',
          transform_value_after_validate => *transform_bar,
      );
      sub transform_bar { 'bar transformed' }

  }

  my $form = MyApp::Form::Test4->new;
  ok( $form );

  my $params = { foo => 'foo', bar => 'bar' };
  $form->process( params => $params );

  is ( $form->field('foo')->value, 'foo transformed', 'foo value was transformed' );
  is ( $form->field('foo')->fif, 'foo', 'foo fif was not transformed' );

  is ( $form->field('bar')->value, 'bar transformed', 'bar value was transformed' );
  is ( $form->field('bar')->fif, 'bar', 'bar fif was not transformed' );
}

done_testing;
