package HTML::MuForm::Field::Submit;
use Moo;
extends 'HTML::MuForm::Field';

has 'value' => ( is => 'rw', default => 'Save' );

sub element_type { 'submit' }


1;
