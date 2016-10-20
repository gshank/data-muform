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
has '+no_update'  => ( default => 1 );

sub build_input_type { 'reset' }

sub no_fif {1}
sub fif { shift->value }

sub base_render_args {
    my $self = shift;
    my $args = $self->next::method(@_);
    $args->{layout_type} = 'element';
    $args->{wrapper} = 'none';
    return $args;
}

1;
