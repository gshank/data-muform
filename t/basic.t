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
   has_field 'optname' => ( temp     => 'First' );
   has_field 'reqname' => ( required => 1 );
   has_field 'somename';
   has_field 'my_selected' => ( type => 'Checkbox' );
   has_field 'must_select' => ( type => 'Checkbox', required => 1 );

   sub field_list
   {
      return [
         { name => 'fruit', type => 'Select' },
         { name => 'optname', temp => 'Second' },
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

is( $form->field('optname')->temp, 'Second', 'got second optname field' );

ok( !$form->process, 'Empty data' );
is_deeply( $form->value, {}, 'no values returns hashref');


done_testing;
