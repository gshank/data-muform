package HTML::MuForm::Field;
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
has 'accessor' => ( is => 'rw', lazy => 1, builder => 'build_accessor' );
sub build_accessor {
    my $self     = shift;
    my $accessor = $self->name;
    $accessor =~ s/^(.*)\.//g if ( $accessor =~ /\./ );
    return $accessor;
}

has 'active' => ( is => 'rw', default => 1 );
has 'disabled' => ( is => 'rw', default => 0 );
has 'noupdate' => ( is => 'rw', default => 0 );


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

sub add_error {
    my ( $self, @message ) = @_;

    unless ( defined $message[0] ) {
        @message = ('Field is invalid');
    }
    @message = @{$message[0]} if ref $message[0] eq 'ARRAY';
    my $out;
    try {
        $out = $self->_localize(@message);
    }
    catch {
        die "Error occurred localizing error message for " . $self->label . ". Check brackets. $_";
    };
    return $self->push_errors($out);;
}

sub push_errors {
    my $self = shift;
    push @{$self->{errors}}, @_;
    if ( $self->parent ) {
        $self->parent->propagate_error($self);
    }
}

sub localize {
}

sub validate {1}

sub validate_field {
    my $self = shift;
}

1;

