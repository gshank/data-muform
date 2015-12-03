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
is( $form->filled_from, 'fields', 'looking at field filled' );
is_deeply( $form->filled, { foo => 'mine', bar => 'yours' }, 'got right filled from fields' );

my $params = {
   foo => 'one',
   bar => 'two',
};

$form->process( params => $params );
is( $form->filled_from, 'params', 'looking at param filled' );
is_deeply( $form->filled, { foo => 'one', bar => 'two' }, 'got right filled from params' );

my $init_obj = { foo => 'three', bar => 'four' };
$form->process( init_object => $init_obj, params => {} );
is( $form->filled_from, 'object', 'looking at object filled' );
is_deeply( $form->filled, $init_obj, 'got right filled from obj' );


done_testing;
