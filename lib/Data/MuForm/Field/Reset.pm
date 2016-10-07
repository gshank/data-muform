package Data::MuForm::Field::Reset;
# ABSTRACT: reset field

use Moo;
extends 'Data::MuForm::Field';

=head1 SYNOPSIS

Use this field to declare a reset field in your form.

   has_field 'reset' => ( type => 'Reset', value => 'Restore' );

Uses the 'reset' widget.

=cut

has 'value' => ( is => 'rw', default => 'Reset' );
has '+noupdate'  => ( default => 1 );

sub build_input_type { 'submit' }

sub fif { shift->value }

1;
