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

=comment
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
   my_selected => 0,
};
is_deeply( $form->fif, $fif, 'fif is correct with missing field' );


$good->{somename} = 'testing';
$form->process($good);

is( $form->field('somename')->value,'testing', 'use input for extra data' );

is( $form->field('my_selected')->value, 0,         'correct value for unselected checkbox' );

ok( !$form->process( {} ), 'empty params no validation second time' );
is( $form->num_errors, 0, 'form doesn\'t have errors with empty params' );

my $bad_1 = {
   reqname => '',
   optname => 'not req',
   fruit   => 4,
};

$DB::single=1;
$form->process($bad_1);

ok( !$form->validated, 'bad 1' );
ok( $form->field('fruit')->has_errors, 'fruit has error' );
ok( $form->field('reqname')->has_errors, 'reqname has error' );
ok( $form->field('must_select')->has_errors, 'must_select has error' );
ok( !$form->field('optname')->has_errors, 'optname has no error' );
is( $form->field('fruit')->id,    "fruit", 'field has id' );
is( $form->field('fruit')->label, 'Fruit', 'field label' );

ok( !$form->process( {} ), 'no leftover params' );
is( $form->num_errors, 0, 'no leftover errors' );
ok( !$form->field('reqname')->has_errors, 'no leftover error in field' );
ok( !$form->field('optname')->fif, 'no lefover fif values' );

=cut

my $init_object = {
   reqname => 'Starting Perl',
   optname => 'Over Again'
};

$form = My::Form->new( init_object => $init_object );
is( $form->field('optname')->value, 'Over Again', 'value with init_obj' );
# non-posted params
$form->process( params => {} );
ok( !$form->validated, 'form did not validate' );
is_deeply ( $form->value, {}, 'empty value, no params' );
is( $form->field('optname')->value, 'Over Again', 'value with init_obj after empty process' );

# FH test used to check that there was a correct ->value hash after ->new.
# This doesn't work because of doing ->process in BUILD. It's an edge case
# and I'm thinking I don't want to support it

my $fif = {
    fruit => '',
    my_selected => '',
    must_select => '',
    somename => '',
    fruit => '',
    reqname => 'Starting Perl',
    optname => 'Over Again',
};
is_deeply( $form->fif, $fif, 'get right fif with init_object' );


done_testing;
