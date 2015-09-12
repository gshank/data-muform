use strict;
use warnings;
use Test::More;
use Data::Dumper;

{
    package MyApp::Form::Test;
    use Moo;
    use HTML::MuForm::Meta;
    extends 'HTML::MuForm';

    has_field 'foo' => ( default => 'mine' );
    has_field 'bar' => ( default => 'yours' );

}

my $form = MyApp::Form::Test->new( no_init_process => 1 );
ok( $form );

$form->process( params => {} );

# process has already been done by BUILD
is( $form->result_from, 'fields', 'looking at field result' );
is_deeply( $form->result, { foo => 'mine', bar => 'yours' }, 'got right result from fields' );

my $params = {
   foo => 'one',
   bar => 'two',
};

$form->process( params => $params );
is( $form->result_from, 'params', 'looking at param result' );
is_deeply( $form->result, { foo => 'one', bar => 'two' }, 'got right result from params' );

my $init_obj = { foo => 'three', bar => 'four' };
$form->process( init_object => $init_obj, params => {} );
is( $form->result_from, 'object', 'looking at object result' );
is_deeply( $form->result, $init_obj, 'got right result from obj' );


done_testing;
