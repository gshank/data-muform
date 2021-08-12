use strict;
use warnings;
use Test::More;

{
    package Test::InputParam;
    use Moo;
    use Data::MuForm::Meta;
    extends 'Data::MuForm';

    has_field 'foo';
    has_field 'base_name' => (
        type => 'Text',
        required => 1,
        input_param=> 'input_name',
    );
}

my $form1 = Test::InputParam->new;
ok( $form1, 'Created Form' );
$form1->process( params=> { input_name => 'This is a mapped input' } );
ok( $form1->validated, 'got good result' );
ok( !$form1->has_errors, 'No errors' );

$form1->process( params => { input_name => '' } );
ok( $form1->ran_validation, 'ran validation' );
ok( ! $form1->validated, 'not validated' );
ok( $form1->has_errors, 'errors for required' );


my $form2 = Test::InputParam->new;
ok( $form2, 'Created Form' );
my %params2 = ( base_name => 'This is a mapped input' );
$form2->process(params=>\%params2);
ok( ! $form2->validated, 'got correct failing result' );
ok( $form2->has_errors, 'Has errors' );

done_testing;
