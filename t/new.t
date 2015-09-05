use strict;
use warnings;
use Test::More;
use Data::Dumper;

{
    package Test::Form;
    use Moo;
    use HTML::MooForm::Meta;
    extends 'HTML::MooForm';

    has_field 'test_field ' => (
        type => 'Text',
        label => 'Test Field',
    );

    has_field 'submit_btn' => (
        type => 'Submit',
        value => 'Save',
    );
}

my $form = Test::Form->new;

ok($form, 'form built');

diag( Dumper($form->_meta_fields) );


done_testing;
