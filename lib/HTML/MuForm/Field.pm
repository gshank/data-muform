package HTML::MuForm::Field;
use Moo;
use Types::Standard -types;
use Try::Tiny;
use Scalar::Util 'blessed';

with 'HTML::MuForm::Common';

=head1 NAME

HTML::MuForm::Field

=head1 DESCRIPTION

Base field for MuForm fields.

=cut

has 'name' => ( is => 'rw', required => 1 );
has 'id' => ( is => 'rw', lazy => 1, builder => 'build_id' );
sub build_id {
   my $self = shift;
   if ( my $meth = $self->get_method('build_id') ) {
       return $meth->($self, @_);
   }
   return $self->html_name;
}
has 'html_name' => ( isa => Str, is => 'rw', lazy => 1, builder => 'build_html_name');
sub build_html_name {
    my $self = shift;
    my $prefix = ( $self->form && $self->form->html_prefix ) ? $self->form->name . "." : '';
    return $prefix . $self->full_name;
}
has 'form' => ( is => 'rw', weak_ref => 1, predicate => 'has_form' );
has 'type' => ( is => 'ro', required => 1, default => 'Text' );
has 'default' => ( is => 'rw' );
has 'input' => ( is => 'rw', predicate => 'has_input', clearer => 'clear_input' );
has 'input_without_param' => ( is => 'rw', predicate => 'has_input_without_param' );
has 'value' => ( is => 'rw', predicate => 'has_value', clearer => 'clear_value' );
has 'init_value' => ( is => 'rw', predicate => 'has_init_value', clearer => 'clear_init_value' );
has 'input_param' => ( is => 'rw', isa => Str );
has 'password' => ( is => 'rw', isa => Bool, default => 0 );
has 'accessor' => ( is => 'rw', lazy => 1, builder => 'build_accessor' );
sub build_accessor {
    my $self     = shift;
    my $accessor = $self->name;
    $accessor =~ s/^(.*)\.//g if ( $accessor =~ /\./ );
    return $accessor;
}
has 'custom' => ( is => 'rw' );
has 'parent' => ( is  => 'rw',   predicate => 'has_parent', weak_ref => 1 );
has 'errors' => ( is => 'rw', isa => ArrayRef, default => sub {[]} );
sub has_errors { my $self = shift; return scalar @{$self->errors}; }
sub all_errors { my $self = shift; return @{$self->errors}; }
sub clear_errors { $_[0]->{errors} = [] }

has 'active' => ( is => 'rw', default => 1, clearer => 'clear_active' );
sub is_inactive { ! $_[0]->active }
has 'disabled' => ( is => 'rw', default => 0 );
has 'noupdate' => ( is => 'rw', default => 0 );
has 'writeonly' => ( is => 'rw', default => 0 );
has 'apply' => ( is => 'rw', default => sub {[]} );
sub has_apply { return scalar @{$_[0]->{apply}} }
has 'base_apply' => ( is => 'rw', default => sub {[]} );  # for field classes
sub has_base_apply { return scalar @{$_[0]->{base_apply}} } # for field definitions
sub has_fields { } # compound fields will override
has 'methods' => ( is => 'rw', isa => HashRef, default => sub {{}} );
sub get_method {
   my ( $self, $meth_name ) = @_;
   return  $self->{methods}->{$meth_name};
}

sub BUILD {
    my $self = shift;

}

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
    if ( my $meth = $self->get_method('build_label' ) ) {
        return $meth->($self);
    }
    my $label = $self->name;
    $label =~ s/_/ /g;
    $label = ucfirst($label);
    return $label;
}
sub loc_label {
    my $self = shift;
    return $self->_localize($self->label);
}

# stub
sub _localize {
   my ( $self, @message ) = @_;
   # TODO
   return $message[0];
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

    return unless $field->has_input;

    my $continue_validation = 1;
    if ( $field->required && ( ! $field->has_input || ! $field->input_defined )) {
        $field->add_error( '[1] is required', $field->label );
        $continue_validation = 0;
    }

    return if !$continue_validation;

    if ( $field->has_fields ) {
        $field->fields_validate;
    }
    # Set value here!
    else {
        my $input = $field->input;
        # TODO: transform here?
        $field->value($input);
    }

    $field->base_validate; # why? also transforms? split out into a 'base_transform' and move the validation?
    $field->apply_actions;
    $field->validate;

    return ! $field->has_errors;
}

sub base_validate { }

sub apply_actions {
    my $self = shift;

    my $error_message;
    local $SIG{__WARN__} = sub {
        my $error = shift;
        $error_message = $error;
        return 1;
    };

    my $is_type = sub {
        my $class = blessed shift or return;
        return $class eq 'MooseX::Types::TypeDecorator' || $class->isa('Type::Tiny');
    };

    my @actions;
    push @actions, @{ $self->base_apply }, @{ $self->apply };
    for my $action ( @actions ) {
        $error_message = undef;
        # the first time through value == input
        my $value     = $self->value;
        my $new_value = $value;
        # Moose constraints
        if ( !ref $action || $is_type->($action) ) {
            $action = { type => $action };
        }
        if ( my $when = $action->{when} ) {
            next unless $self->match_when($when);
        }
        if ( exists $action->{type} ) {
            my $tobj;
            if ( $is_type->($action->{type}) ) {
                $tobj = $action->{type};
            }
            else {
                my $type = $action->{type};
                $tobj = Moose::Util::TypeConstraints::find_type_constraint($type) or
                    die "Cannot find type constraint $type";
            }
            if ( $tobj->has_coercion && $tobj->validate($value) ) {
                eval { $new_value = $tobj->coerce($value) };
                if ($@) {
                    if ( $tobj->has_message ) {
                        $error_message = $tobj->message->($value);
                    }
                    else {
                        $error_message = $@;
                    }
                }
                else {
                    $self->value($new_value);
                }

            }
            $error_message ||= $tobj->validate($new_value);
        }
        # now maybe: http://search.cpan.org/~rgarcia/perl-5.10.0/pod/perlsyn.pod#Smart_matching_in_detail
        # actions in a hashref
        elsif ( ref $action->{check} eq 'CODE' ) {
            if ( !$action->{check}->($value, $self) ) {
                $error_message = $self->get_message('wrong_value');
            }
        }
        elsif ( ref $action->{check} eq 'Regexp' ) {
            if ( $value !~ $action->{check} ) {
                $error_message = [$self->get_message('no_match'), $value];
            }
        }
        elsif ( ref $action->{check} eq 'ARRAY' ) {
            if ( !grep { $value eq $_ } @{ $action->{check} } ) {
                $error_message = [$self->get_message('not_allowed'), $value];
            }
        }
        elsif ( ref $action->{transform} eq 'CODE' ) {
            $new_value = eval {
                no warnings 'all';
                $action->{transform}->($value, $self);
            };
            if ($@) {
                $error_message = $@ || $self->get_message('error_occurred');
            }
            else {
                $self->_set_value($new_value);
            }
        }
        if ( defined $error_message ) {
            my @message = ref $error_message eq 'ARRAY' ? @$error_message : ($error_message);
            if ( defined $action->{message} ) {
                my $act_msg = $action->{message};
                if ( ref $act_msg eq 'CODE' ) {
                    $act_msg = $act_msg->($value, $self, $error_message);
                }
                if ( ref $act_msg eq 'ARRAY' ) {
                    @message = @{$act_msg};
                }
                elsif ( ref \$act_msg eq 'SCALAR' ) {
                    @message = ($act_msg);
                }
            }
            $self->add_error(@message);
        }
    }
}
#====================================================================
# Filling
#====================================================================

sub fill_from_params {
    my ( $self, $result, $input, $exists ) = @_;

    if ( $exists ) {
        $result->{$self->name} = $input;
        $self->input($input);
    }
    elsif ( $self->disabled ) {
    }
    elsif ( $self->has_input_without_param ) {
        $self->input($self->input_without_param);
    }
    return;
}

sub fill_from_object {
    my ( $self, $result, $value ) = @_;

    $self->value($value);
    $result->{$self->name} = $value;

    if ( $self->form ) {
        $self->form->init_value( $self, $value );
    }
    else {
        $self->init_value($value);
        #$result->_set_value($value);
    }
    $self->value(undef) if $self->writeonly;
    # $result->_set_field_def($self);
    return;
}

sub fill_from_fields {
    my ( $self, $result ) = @_;

    if ( $self->disabled && $self->has_init_value ) {
        $self->value($self->init_value);
        $result->{$self->name} = $self->init_value;
    }
    elsif ( my @values = $self->get_default_value ) {
        # TODO
        #if ( $self->has_inflate_default_method ) {
        #    @values = $self->inflate_default(@values);
        #}
        my $value = @values > 1 ? \@values : shift @values;
        if ( defined $value ) {
            $self->init_value($value);
            $self->value($value);
            $result->{$self->name} = $value;
        }
    }
    return;

}


sub clear_data {
    my $self = shift;

    $self->clear_input;
    $self->clear_value;
    $self->clear_errors;
}

sub get_default_value {
    my $self = shift;
    if ( my $meth = $self->get_method('default') ) {
        return $meth->($self);
    }
    elsif ( defined $self->default ) {
        return $self->default;
    }
    return;
}


#====================================================================
# Messages
#====================================================================

has 'messages' => ( is => 'rw', isa => HashRef, default => sub {{}} );
sub _get_field_message { my ($self, $msg) = @_; return $self->{messages}->{$msg}; }
sub _has_field_message { my ($self, $msg) = @_; exists $self->{messages}->{$msg}; }
sub set_message { my ($self, $msg, $value) = @_; $self->{messages}->{$msg} = $value; }


our $class_messages = {
    'field_invalid'   => 'field is invalid',
    'range_too_low'   => 'Value must be greater than or equal to [_1]',
    'range_too_high'  => 'Value must be less than or equal to [_1]',
    'range_incorrect' => 'Value must be between [_1] and [_2]',
    'wrong_value'     => 'Wrong value',
    'no_match'        => '[_1] does not match',
    'not_allowed'     => '[_1] not allowed',
    'error_occurred'  => 'error occurred',
    'required'        => '[_1] field is required',
    'unique'          => 'Duplicate value for [_1]',
};

sub get_class_messages  {
    my $self = shift;
    my $messages = { %$class_messages };
    return $messages;
}

sub get_message {
    my ( $self, $msg ) = @_;

    # first look in messages set on individual field
    return $self->_get_field_message($msg)
       if $self->_has_field_message($msg);
    # then look at form messages
    return $self->form->_get_form_message($msg)
       if $self->has_form && $self->form->_has_form_message($msg);
    # then look for messages up through inherited field classes
    return $self->get_class_messages->{$msg};
}
sub all_messages {
    my $self = shift;
    my $form_messages = $self->has_form ? $self->form->messages : {};
    my $field_messages = $self->messages || {};
    my $lclass_messages = $self->my_class_messages || {};
    return {%{$lclass_messages}, %{$form_messages}, %{$field_messages}};
}


1;

