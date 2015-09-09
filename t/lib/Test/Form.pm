package Test::Form;
use Moo;
use HTML::MuForm::Meta;
extends 'HTML::MuForm';
with 'Test::FormRole';

has_field 'foo';
has_field 'bar';

has_field 'submit_btn' => ( type => 'Submit' );

1;
