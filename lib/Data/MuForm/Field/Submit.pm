package Data::MuForm::Field::Submit;
use Moo;
extends 'Data::MuForm::Field';

has 'value' => ( is => 'rw', default => 'Save' );
has '+noupdate'  => ( default => 1 );

sub build_input_type { 'submit' }

sub no_fif {1}
sub fif { shift->value }


1;
