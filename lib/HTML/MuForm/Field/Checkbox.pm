package HTML::MuForm::Field::Checkbox;
use Moo;
extends 'HTML::MuForm::Field';

has 'size' => ( is => 'rw', default => 0 );

has 'checkbox_value' => ( is => 'rw', default => 1 );
has '+input_without_param' => ( default => 0 );
has 'option_label'         => ( is => 'rw' );
has 'option_wrapper'       => ( is => 'rw' );

sub element_type { 'checkbox' }

sub validate {
    my $self = shift;
    $self->add_error('You must select this', $self->label) if( $self->required && !$self->value );
}

1;
