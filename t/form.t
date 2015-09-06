use strict;
use warnings;
use Test::More;
use Data::Dumper;

{
    package Test::Form;
    use Moo;
    use HTML::MuForm::Meta;
    extends 'HTML::MuForm';

    has_field 'test_field' => (
        type => 'Text',
        label => 'Test Field',
        required => 1,
    );

    has_field 'submit_btn' => (
        type => 'Submit',
        value => 'Save',
    );
}

my $form = Test::Form->new;

ok($form, 'form built');

is ( scalar ( @{$form->_meta_fields} ), 2, 'two meta fields' );
is ( $form->num_fields, 2, 'two fields' );

my $field = $form->field('test_field');

ok( $field, 'field method works' );

my $params = {
    test_field => 'something',
};

$form->process( params => $params );
ok( $form->has_params, 'form has_params correct');

ok( $form->validated, 'form validated' );

$params = { test_field => '' };

$form->process( params => $params );
ok( ! $form->validated, 'form did not validate' );

done_testing;
