use strict;
use warnings;
use Test::More;
use Data::Dumper;

use lib 't/lib';

use_ok( 'Test::Form' );

my $form = Test::Form->new;
ok($form, 'form built');

my @meta_fields = $form->_meta_fields;
is( scalar @meta_fields, 5, 'there are 5 meta fields in the form' );

is( $form->num_fields, 5, 'five fields built' );

my $expected =  [
   { 'name' => 'foo' },
   { 'name' => 'bar' },
   { 'type' => 'Submit',
     'name' => 'submit_btn'
   },
   { 'name' => 'flotsam' },
   { 'name' => 'jetsam' },
];

is_deeply( \@meta_fields, $expected, 'got the meta fields we expected' );

done_testing;
