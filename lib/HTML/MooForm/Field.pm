package HTML::MooForm::Field;
use Moo;

has 'name' => ( is => 'rw', required => 1 );
has 'type' => ( is => 'ro', required => 1, default => 'Text' );
has 'default' => ( is => 'rw' );
has 'input' => ( is => 'rw' );
sub has_input {
    my $self = shift;
    return defined($self->input);
}
has 'value' => ( is => 'rw' );
sub has_value {
    my $self = shift;
    return defined( $self->value);
}
has 'active' => ( is => 'rw', default => 1 );

sub fif {
    my $self = shift;
    return unless $self->active;
    return $self->input if $self->has_input;
    return $self->value if $self->has_value;
    if ( $self->has_value ) {
        if ( $self->can_deflate ) {
            return $self->deflate($self->value);
        }
        return $self->value;
    }
    return '';
}


#===================
#  Rendering
#===================

has 'label' => ( is => 'rw', lazy => 1, builder => 'build_label' );
sub build_label {
    my $self = shift;
}

has 'element_type' => ( is => 'rw', lazy => 1, builder => 'build_element_type' );

# could have everything in one big "pass to the renderer" hash?
has 'layout' => ( is => 'rw' );
has 'layout_group' => ( is => 'rw' );
has 'order' => ( is => 'rw' );


#===================
#  Validation
#===================

has 'required' => ( is => 'rw', default => 0 );

sub validate {1}

sub validate_field {
    my $self = shift;
}

1;

