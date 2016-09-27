use strict;
use warnings;
use Test::More;

{
    package MyApp::Form::Test;
    use Moo;
    use Data::MuForm::Meta;
    extends 'Data::MuForm';

    has_field 'foo' => (
        type => 'Text',
        transform_input => sub { 'foo transformed' },
    );
    has_field 'bar' => (
        type => 'Text',
        transform_input => *transform_bar,
    );
    sub transform_bar { 'bar transformed' }

}

my $form = MyApp::Form::Test->new;
ok( $form );

my $params = { foo => 'foo', bar => 'bar' };
$form->process( params => $params );

is ( $form->field('foo')->value, 'foo transformed', 'foo input was transformed' );
is ( $form->field('bar')->value, 'bar transformed', 'bar input was transformed' );

done_testing;
