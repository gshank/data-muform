package HTML::MuForm::Field;
use Moo;
use Types::Standard -types;
use Try::Tiny;

has 'name' => ( is => 'rw', required => 1 );
has 'form' => ( is => 'rw' );
has 'type' => ( is => 'ro', required => 1, default => 'Text' );
has 'default' => ( is => 'rw' );
has 'input' => ( is => 'rw', predicate => 'has_input', clearer => 'clear_input' );
has 'value' => ( is => 'rw', predicate => 'has_value', clearer => 'clear_value' );
has 'input_param' => ( is => 'rw', isa => Str );
has 'accessor' => ( is => 'rw', lazy => 1, builder => 'build_accessor' );
sub build_accessor {
    my $self     = shift;
    my $accessor = $self->name;
    $accessor =~ s/^(.*)\.//g if ( $accessor =~ /\./ );
    return $accessor;
}
has 'parent' => ( is  => 'rw',   predicate => 'has_parent', weak_ref => 1 );
has 'errors' => ( is => 'rw', isa => ArrayRef, clearer => 'clear_errors', default => sub {[]} );
sub has_errors { my $self = shift; return scalar @{$self->errors}; }

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


sub full_name {
    my $field = shift;

    my $name = $field->name;
    my $parent_name;
    # field should always have a parent unless it's a standalone field test
    if ( $field->parent ) {
        $parent_name = $field->parent->full_name;
    }
    return $name unless defined $parent_name && length $parent_name;
    return $parent_name . '.' . $name;
}

sub full_accessor {
    my $field = shift;

    my $parent = $field->parent;
    if( $field->is_contains ) {
        return '' unless $parent;
        return $parent->full_accessor;
    }
    my $accessor = $field->accessor;
    my $parent_accessor;
    if ( $parent ) {
        $parent_accessor = $parent->full_accessor;
    }
    return $accessor unless defined $parent_accessor && length $parent_accessor;
    return $parent_accessor . '.' . $accessor;
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
has 'order' => ( is => 'rw', isa => Int, default => 0 );


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
        $out = $self->localize(@message);
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
        $self->parent->add_error_field($self);
    }
}

sub localize {
    my ( $self, @message ) = @_;
    # stub out for now
    return $message[0];
}

sub clear {
    my $self = shift;
    $self->clear_input;
    $self->clear_value;
}

#====================================================================
# Validation
#====================================================================

sub input_defined {
    my ($self) = @_;
    return unless $self->has_input;
    return has_some_value( $self->input );
}

sub has_some_value {
    my $x = shift;

    return unless defined $x;
    return $x =~ /\S/ if !ref $x;
    if ( ref $x eq 'ARRAY' ) {
        for my $elem (@$x) {
            return 1 if has_some_value($elem);
        }
        return 0;
    }
    if ( ref $x eq 'HASH' ) {
        for my $key ( keys %$x ) {
            return 1 if has_some_value( $x->{$key} );
        }
        return 0;
    }
    return 1 if blessed($x);    # true if blessed, otherwise false
    return 1 if ref( $x );
    return;
}



sub validate {1}

sub validate_field {
    my $field = shift;

    my $continue_validation = 1;
    if ( $field->required && ( ! $field->has_input || ! $field->input_defined )) {
        $field->add_error( '[1] is required', $field->label );
        $continue_validation = 0;
    }

    return if !$continue_validation;

    $field->validate;

    return ! $field->has_errors;
}

#====================================================================
# Filling
#====================================================================

sub fill_from_input {
    my ( $self, $result, $input, $exists ) = @_;

    if ( $exists ) {
        $result->{$self->name} = $input;
        $self->input($input);
    }
}

sub clear_data {
    my $self = shift;
    $self->clear_input;
    $self->clear_value;
    $self->clear_active;
}


1;

