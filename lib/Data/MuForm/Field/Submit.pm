package Data::MuForm::Field::Submit;
# ABSTRACT: Submit field

use Moo;
extends 'Data::MuForm::Field';

has 'value' => ( is => 'rw', default => 'Save' );
has '+no_update'  => ( default => 1 );

sub build_input_type { 'submit' }

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
