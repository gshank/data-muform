package Data::MuForm::Field::Hidden;
# ABSTRACT: hidden field

use Moo;
extends 'Data::MuForm::Field::Text';

has '+html5_type_attr' => ( default => 'hidden' );

sub build_input_type { 'hidden' }

=head1 DESCRIPTION

This is a 'convenience' text field that uses the 'hidden' type.

=cut

sub base_render_args {
    my $self = shift;
    my $args = $self->next::method(@_);
    $args->{layout_type} = 'element';
    return $args;
}

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
