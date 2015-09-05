package HTML::MooForm::Field::Submit;
use Moo;
extends 'HTML::MooForm::Field';

has 'value' => ( is => 'rw', default => 'Save' );

sub element_type { 'submit' }


1;
