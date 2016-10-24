package Data::MuForm::Field::Button;
# ABSTRACT: Button field

use Moo;
extends 'Data::MuForm::Field';

has 'value' => ( is => 'rw', default => 'Save' );
has '+no_update'  => ( default => 1 );

sub build_form_element { 'button' }
sub build_input_type { 'button' }

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
