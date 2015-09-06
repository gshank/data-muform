use strict;
use warnings;
use Test::More;

use_ok('HTML::MuForm');

{

   package My::Form;
   use Moo;
   use HTML::MuForm::Meta;
   extends 'HTML::MuForm';

   has '+name'         => ( default  => 'testform_' );

   has_field 'optname' => ( label     => 'First' );
   has_field 'reqname' => ( required => 1 );
   has_field 'somename';
   has_field 'my_selected' => ( type => 'Checkbox' );
   has_field 'must_select' => ( type => 'Checkbox', required => 1 );

   sub field_list
   {
      return [
         { name => 'fruit', type => 'Select' },
         { name => 'optname', label => 'Second' },
      ];
   }

   sub options_fruit
   {
      return (
         1 => 'apples',
         2 => 'oranges',
         3 => 'kiwi',
      );
   }
}

my $form = My::Form->new;

is( $form->num_fields, 6, 'got six fields' );
is( $form->field('optname')->label, 'Second', 'got second optname field' );

# process with empty params
ok( !$form->process, 'Empty data' );
is_deeply( $form->value, {}, 'no values returns hashref');
ok( ! $form->validated, 'form did not validate' );
is( $form->ran_validation, 0, 'ran_validation correct' );

$form->clear;
ok( ! $form->field('somename')->has_input, 'field no input after clear' );
ok( ! $form->field('somename')->has_value, 'no has_value after clear' );

# now try some good params
my $good = {
   reqname     => 'hello',
   optname     => 'not req',
   fruit       => 2,
   must_select => 1,
};

$form->process( params => $good );
my $field = $form->field('must_select');
is( $field->input, 1, 'field has right input' );
ok( ! $field->has_errors, 'must_select field no errors' );

ok( ! $form->field('reqname')->has_errors, 'reqname field no errors' );
ok( ! $form->field('optname')->has_errors, 'optname field no errors' );
ok( ! $form->field('fruit')->has_errors, 'fruit field no errors' );
ok( $form->validated, 'Good data' );


is( $form->field('somename')->value, undef, 'no value for somename' );
ok( !$form->field('somename')->has_value, 'predicate no value' );
my $fif = {
   reqname     => 'hello',
   optname     => 'not req',
   fruit       => 2,
   must_select => 1,
};
is_deeply( $form->fif, $fif, 'fif is correct with missing field' );


$good->{somename} = 'testing';
$form->process($good);

is( $form->field('somename')->value,'testing', 'use input for extra data' );

is( $form->field('my_selected')->value, 0,         'correct value for unselected checkbox' );

ok( !$form->process( {} ), 'empty params no validation second time' );
is( $form->num_errors, 0, 'form doesn\'t have errors with empty params' );



done_testing;
