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

# transform_value_to_fif
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

done_testing;
