use strict;
use warnings;
use Test::More;

{
    package MyApp::Form::Test;
    use Moo;
    use Data::MuForm::Meta;
    extends 'Data::MuForm';

    has_field 'foo' => ( type => 'List', valid => ['one', 'three', 'five'], required => 1 );
    has_field 'bar';

}

my $form = MyApp::Form::Test->new;
ok( $form );

my $params = {
  foo => 'one',
  bar => 'two',
};

$form->process( params => $params );

ok($form->validated, 'form validated');
my $fif = {
  foo => ['one'],
  bar => 'two',
};
is_deeply( $form->fif, $fif, 'got expected fif' );
is_deeply( $form->values, $fif, 'got expected values' );

$params = {
  foo => '',
  bar => 'two',
};
$form->process( params => $params );
ok( $form->has_errors, 'form has errors' );

$params = {
  foo => ['one', 'three'],
  bar => 'two',
};
$form->process( params => $params );
ok( $form->validated, 'form validated with multiple values for foo' );

done_testing;
