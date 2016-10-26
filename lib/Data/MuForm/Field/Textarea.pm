package Data::MuForm::Field::Textarea;
# ABSTRACT: textarea input

use Moo;
extends 'Data::MuForm::Field::Text';
use Types::Standard -types;

sub build_form_element { 'textarea' }

has 'cols'    => ( is => 'rw', default => 40 );
has 'rows'    => ( is => 'rw', default => 5 );

sub base_render_args {
    my $self = shift;
    my $args = $self->next::method(@_);
    $args->{element_attr}->{cols} = $self->cols if $self->cols;
    $args->{element_attr}->{rows} = $self->rows if $self->rows;
    return $args;
}


=head1 Summary

For HTML textarea

=cut

1;
