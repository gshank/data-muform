package HTML::MuForm::Field::Submit;
use Moo;
extends 'HTML::MuForm::Field';

has 'value' => ( is => 'rw', default => 'Save' );
has '+noupdate'  => ( default => 1 );

sub build_input_type { 'submit' }

sub fif { }


1;
