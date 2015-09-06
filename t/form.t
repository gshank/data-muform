use strict;
use warnings;
use Test::More;
use Data::Dumper;

{
    package Test::Form;
    use Moo;
    use HTML::MuForm::Meta;
    extends 'HTML::MuForm';
    use Types::Standard ':all';

    has_field 'foo' => (
        type => 'Text',
        label => 'Test Field',
        required => 1,
    );

    has_field 'bar' => (
        type => 'Text',
        label => 'Testing!',
        apply => [],
    );

    has_field 'submit_btn' => (
        type => 'Submit',
        value => 'Save',
    );
}

my $form = Test::Form->new;

ok($form, 'form built');

is ( scalar ( @{$form->_meta_fields} ), 3, 'two meta fields' );
is ( $form->num_fields, 3, 'two fields' );

my $field = $form->field('foo');

ok( $field, 'field method works' );

my $params = {
    foo => 'something',
};

$form->process( params => $params );
ok( $form->has_params, 'form has_params correct');

ok( $form->validated, 'form validated' );
is_deeply( $form->fif, { foo => 'something' }, 'fif correct when valid' );

$params = { foo => '' };

$form->process( params => $params );
ok( ! $form->validated, 'form did not validate' );
is ( $form->num_error_fields, 1, 'one error field' );

is ( $form->num_errors, 1, 'one error');

is_deeply( $form->fif, { foo => '' }, 'fif correct when error' );


done_testing;
