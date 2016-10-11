package Data::MuForm::Field::Text;
# ABSTRACT: Text field
use Moo;
extends 'Data::MuForm::Field';

has 'size' => ( is => 'rw', default => 0 );
has 'maxlength' => ( is => 'rw' );
has 'minlength' => ( is => 'rw', default => '0' );

sub build_input_type { 'text' }

our $class_messages = {
    'text_maxlength' => 'Field should not exceed {maxlength} characters. You entered {length}',
    'text_minlength' => 'Field must be at least {minlength} characters. You entered {length}',
};

sub get_class_messages {
    my $self = shift;
    my $messages = {
        %{ $self->next::method },
        %$class_messages,
    };
    return $messages;
}

sub base_render_args {
    my $self = shift;
    my $args = $self->next::method(@_);
    $args->{element_attr}->{size} = $self->size if $self->size;
    $args->{element_attr}->{maxlength} = $self->maxlength if $self->maxlength;
    $args->{element_attr}->{minlength} = $self->minlenght if $self->minlength;
    return $args;
}

sub validate {
    my $field = shift;

    return unless $field->next::method;
    my $value = $field->input;
    # Check for max length
    if ( my $maxlength = $field->maxlength ) {
        return $field->add_error( $field->get_message('text_maxlength'),
            maxlength => $maxlength, length => length $value, field_label =>$field->loc_label )
            if length $value > $maxlength;
    }

    # Check for min length
    if ( my $minlength = $field->minlength ) {
        return $field->add_error(
            $field->get_message('text_minlength'),
            minlength => $minlength, length => length $value, field_label => $field->loc_label )
            if length $value < $minlength;
    }
    return 1;
}

1;
