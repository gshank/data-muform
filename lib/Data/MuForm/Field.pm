package Data::MuForm::Field;
use Moo;
use Types::Standard -types;
use Try::Tiny;
use Scalar::Util 'blessed';
use Data::Clone ('data_clone');
use Data::MuForm::Localizer;
# causes errors if I use this. Figure out later how
# to use Moose types
#use Moose::Util::TypeConstraints;

with 'Data::MuForm::Common';

=head1 NAME

Data::MuForm::Field

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
has 'value' => ( is => 'rw', predicate => '_has_value', clearer => 'clear_value' );
# TODO: put this in to fix tags, but it didn't help. Is this correct?
sub has_value {
  my $self = shift;
  return 0 unless $self->_has_value;
  return 0 if ( ref $self->value eq 'ARRAY' && scalar @{$self->value} == 0 );
  return 0 if ( ref $self->value eq 'HASH' && scalar( keys %{$self->value} ) == 0 );
  return 1;
}
has 'init_value' => ( is => 'rw', predicate => 'has_init_value', clearer => 'clear_init_value' );
has 'no_value_if_empty' => ( is => 'rw', isa => Bool );
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
sub clear_error_fields { }

has 'active' => ( is => 'rw', default => 1 );
sub is_inactive { ! $_[0]->active }
has 'disabled' => ( is => 'rw', default => 0 );
has 'noupdate' => ( is => 'rw', default => 0 );
has 'writeonly' => ( is => 'rw', default => 0 );
has 'is_contains' => ( is => 'rw', isa => Bool );
has 'apply' => ( is => 'rw', default => sub {[]} ); # for field defnitions
sub has_apply { return scalar @{$_[0]->{apply}} }
has 'base_apply' => ( is => 'rw', default => sub {[]} );  # for field classes
sub has_base_apply { return scalar @{$_[0]->{base_apply}} }
has 'trim' => (
    is      => 'rw',
    default => sub { { transform => \&default_trim } }
);
sub default_trim {
    my $value = shift;
    return unless defined $value;
    my @values = ref $value eq 'ARRAY' ? @$value : ($value);
    for (@values) {
        next if ref $_ or !defined;
        s/^\s+//;
        s/\s+$//;
    }
    return ref $value eq 'ARRAY' ? \@values : $values[0];
}
sub has_fields { } # compound fields will override
has 'methods' => ( is => 'rw', isa => HashRef, default => sub {{}} );
sub get_method {
   my ( $self, $meth_name ) = @_;
   return  $self->{methods}->{$meth_name};
}

has 'validate_when_empty' => ( is => 'rw', isa => Bool );
has 'not_nullable' => ( is => 'rw', isa => Bool );
sub is_repeatable {}
sub is_compound {}

#=================
# Rendering
#=================
has 'html5_type_attr' => ( is => 'rw' );
has 'render_args' => ( is => 'rw', isa => HashRef, builder => 'build_render_args' );
sub build_render_args {{}}
has 'renderer' => (
  is => 'rw',
  builder => 'build_renderer',
);
sub build_renderer {
  my $self = shift;
  require Data::MuForm::Renderer::Standard;
  return Data::MuForm::Renderer::Standard->new;
}
sub get_render_args {
  my ( $self, %args ) = @_;
  my $render_args = {
    %{ $self->render_args },
    %args,
    form_element => $self->form_element,
    input_type => $self->input_type,
    id => $self->id,
    label => $self->label,
    name => $self->html_name,
  };
}
sub render {
  my ( $self, %args ) = @_;
  my $render_args = $self->get_render_args(%args);
  return $self->renderer->render_field($render_args);
}

sub BUILD {
    my $self = shift;

}

sub fif {
    my $self = shift;
    return unless $self->active;
    return $self->input if $self->has_input;
    if ( $self->has_value ) {
      my $value = $self->value;
      $value = $self->transform_value_to_fif->($self, $value) if $self->has_transform_value_to_fif;
      return $value;
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


#====================
# Localization
#====================

sub _localize {
   my ( $self, @message ) = @_;
   return $self->localizer->loc_($message[0]);
}

has 'language' => ( is => 'rw', builder => 'build_language' );
sub build_language { 'en' }
has 'localizer' => (
    is => 'rw', builder => 'build_localizer',
);
sub build_localizer {
    my $self = shift;
    return Data::MuForm::Localizer->new(
      language => $self->language,
    );
}

#====================
# Rendering
#====================
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
has 'form_element' => ( is => 'rw', lazy => 1, builder => 'build_form_element' );
sub build_form_element { 'input' }
has 'input_type' => ( is => 'rw', lazy => 1, builder => 'build_input_type' );
sub build_input_type { 'text' }

# could have everything in one big "pass to the renderer" hash?
has 'layout' => ( is => 'rw' );
has 'layout_group' => ( is => 'rw' );
has 'order' => ( is => 'rw', isa => Int, default => 0 );


#===================
#  Errors
#===================

# handles message with and without variables
sub add_error {
    my ( $self, @message ) = @_;
    my $out;
    if ( $message[0] !~ /{/ ) {
        $out = $self->localizer->loc_($message[0]);
    }
    else {
        $out = $self->localizer->loc_x(@message);
    }
    return $self->push_errors($out);
}

sub add_error_px {
    my ( $self, @message ) = @_;
    my $out = $self->localizer->loc_px(@message);
    return $self->push_errors($out);;
}

sub add_error_nx {
    my ( $self, @message ) = @_;
    my $out = $self->localizer->loc_nx(@message);
    return $self->push_errors($out);
}

sub add_error_npx {
    my ( $self, @message ) = @_;
    my $out = $self->localizer->loc_npx(@message);
    return $self->push_errors($out);;
}



sub push_errors {
    my $self = shift;
    push @{$self->{errors}}, @_;
    if ( $self->parent ) {
        $self->parent->add_error_field($self);
    }
}

sub clear { shift->clear_data }

#===================
#  Transforms
#===================

# these are all coderefs
has 'transform_param_to_input' => ( is => 'rw', predicate => 'has_transform_param_to_input' );
has 'transform_input_to_value' => ( is => 'rw', predicate => 'has_transform_input_to_value' );
has 'transform_default_to_value' => ( is => 'rw', predicate => 'has_transform_default_to_value' );
has 'transform_value_after_validate' => ( is => 'rw', predicate => 'has_transform_value_after_validate' );
has 'transform_value_to_fif' => ( is => 'rw', predicate => 'has_transform_value_to_fif' );

#====================================================================
# Validation
#====================================================================

has 'required' => ( is => 'rw', default => 0 );
has 'required_when' => ( is => 'rw', isa => HashRef, predicate => 'has_required_when' );
has 'unique' => ( is => 'rw', isa => Bool, predicate => 'has_unique' );
sub validated { !$_[0]->has_errors && $_[0]->has_input }

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
    my $self = shift;

    return unless $self->has_input;

    my $continue_validation = 1;
    if ( ( $self->required ||
         ( $self->has_required_when && $self->match_when($self->required_when) ) ) &&
         ( ! $self->has_input || ! $self->input_defined )) {
        $self->add_error( $self->get_message('required'), field_label => $self->label );
        if( $self->has_input ) {
            $self->not_nullable ? $self->value($self->input) : $self->value(undef);
        }

        $continue_validation = 0;
    }
    elsif ( $self->is_repeatable ) { }
    elsif ( !$self->has_input ) {
        $continue_validation = 0;
    }
    elsif ( !$self->input_defined ) {
        if ( $self->not_nullable ) {
            $self->value($self->input);
            # handles the case where a compound field value needs to have empty subfields
            $continue_validation = 0 unless $self->is_compound;
        }
        elsif ( $self->no_value_if_empty || $self->is_contains ) {
            $continue_validation = 0;
        }
        else {
            $self->value(undef);
            $continue_validation = 0;
        }
    }
    return if ( !$continue_validation && !$self->validate_when_empty );


    if ( $self->has_fields ) {
        $self->fields_validate;
    }
    else {
        my $input = $self->input;
        $input = $self->transform_input_to_value->($self, $input) if $self->has_transform_input_to_value;
        $self->value($input);
    }

    $self->base_validate; # why? also transforms? split out into a 'base_transform' and move the validation?
    $self->apply_actions;
    $self->validate;

    if ( $self->has_transform_value_after_validate ) {
        my $value = $self->value;
        $value = $self->transform_value_after_validate->($self, $value);
        $self->value($value);
    }

    return ! $self->has_errors;
}

sub transform_and_set_input {
  my ( $self, $input ) = @_;
  $input = $self->transform_param_to_input->($self, $input) if $self->has_transform_param_to_input;
  $self->input($input);
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
    push @actions, $self->trim if $self->trim;
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
                $error_message = [$self->get_message('no_match'), 'value', $value];
            }
        }
        elsif ( ref $action->{check} eq 'ARRAY' ) {
            if ( !grep { $value eq $_ } @{ $action->{check} } ) {
                $error_message = [$self->get_message('not_allowed'), 'value', $value];
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
                $self->value($new_value);
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

sub match_when {
    my ( $self, $when ) = @_;

    my $matched = 0;
    foreach my $key ( keys %$when ) {
        my $check_against = $when->{$key};
        my $from_form = ( $key =~ /^\+/ );
        $key =~ s/^\+//;
        my $field = $from_form ? $self->form->field($key) : $self->parent->subfield( $key );
        unless ( $field ) {
            warn "field '$key' not found processing 'when' for '" . $self->full_name . "'";
            next;
        }
        my $field_fif = defined $field->fif ? $field->fif : '';
        if ( ref $check_against eq 'CODE' ) {
            $matched++
                if $check_against->($field_fif, $self);
        }
        elsif ( ref $check_against eq 'ARRAY' ) {
            foreach my $value ( @$check_against ) {
                $matched++ if ( $value eq $field_fif );
            }
        }
        elsif ( $check_against eq $field_fif ) {
            $matched++;
        }
        else {
            $matched = 0;
            last;
        }
    }
    return $matched;
}

#====================================================================
# Filling
#====================================================================

sub fill_from_params {
    my ( $self, $input, $exists ) = @_;

    if ( $exists ) {
        $self->transform_and_set_input($input);
    }
    elsif ( $self->disabled ) {
    }
    elsif ( $self->has_input_without_param ) {
        $self->transform_and_set_input($self->input_without_param);
    }
    return;
}

sub fill_from_object {
    my ( $self, $value ) = @_;

    $self->value($value);

    if ( $self->form ) {
        $self->form->init_value( $self, $value );
    }
    else {
        $self->init_value($value);
        #$result->_set_value($value);
    }
    $self->value(undef) if $self->writeonly;

    return;
}

sub fill_from_fields {
    my ( $self, ) = @_;

    if ( $self->disabled && $self->has_init_value ) {
        $self->value($self->init_value);
    }
    elsif ( my @values = $self->get_default_value ) {
        if ( $self->has_transform_default_to_value ) {
            @values = $self->transform_default_to_value->($self, @values);
        }
        my $value = @values > 1 ? \@values : shift @values;
        if ( defined $value ) {
            $self->init_value($value);
            $self->value($value);
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
    'range_incorrect' => 'Value must be between {start} and {end}',
    'wrong_value'     => 'Wrong value',
    'no_match'        => '[_1] does not match',
    'not_allowed'     => '[_1] not allowed',
    'error_occurred'  => 'error occurred',
    'required'        => "'{field_label}' field is required",
    'unique'          => 'Duplicate value for [_1]',   # this is used in the DBIC model
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

sub clone {
    my $self = shift;
    return data_clone($self);
}

sub get_result {
    my $self = shift;
    my $result = {
        name => $self->name,
        full_name => $self->full_name,
        id => $self->id,
        label => $self->label,
        render_args => $self->render_args,
        fif => $self->fif,
    };
    $result->{errors} = $self->errors if $self->has_errors;
    return $result;
}

1;

