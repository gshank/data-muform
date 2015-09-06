package Test::Form;
use Moo;
use HTML::MuForm::Meta;
extends 'HTML::MuForm';

has_field 'foo';
has_field 'bar';

with 'Test::FormRole';

has_field 'submit_btn' => ( type => 'Submit' );

1;
