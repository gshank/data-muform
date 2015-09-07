use strict;
use warnings;
use Test::More;
use Data::Dumper;

use lib 't/lib';

use_ok( 'Test::Form' );

my $form = Test::Form->new;
ok($form, 'form built');

my $meta_fields = $form->saved_meta_fields;

is( scalar @$meta_fields, 5, 'there are 5 meta fields' );

my $expected =  [
   { 'name' => 'foo' },
   { 'name' => 'bar' },
   { 'name' => 'flotsam' },
   { 'name' => 'jetsam' },
   { 'type' => 'Submit',
     'name' => 'submit_btn'
   }
];

is_deeply( $meta_fields, $expected, 'got the meta fields we expected' );

done_testing;
