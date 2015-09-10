package HTML::MuForm;
use Moo;
use HTML::MuForm::Meta;

=head1 NAME

HTML::MuForm

=head1 DESCRIPTION

Moo conversion of HTML::FormHandler.

=cut

with 'HTML::MuForm::Model';
with 'HTML::MuForm::Fields';
with 'HTML::MuForm::Common';

use Types::Standard -types;
use Class::Load ('load_optional_class');
use Data::Clone;
use HTML::MuForm::Params;

has 'name' => ( is => 'ro', isa => Str, builder => 'build_name');
sub build_name {
    my $self = shift;
    my $class = ref $self;
    my  ( $name ) = ( $class =~ /.*::(.*)$/ );
    return $name;
}
has 'submitted' => ( is => 'rw', default => undef );  # three values: 0, 1, undef
has 'processed' => ( is => 'rw', default => 0 );
has 'no_init_process' => ( is => 'rw', default => 0 );

has 'ran_validation' => ( is => 'rw', default => 0 );
has '_params' => ( is => 'rw', isa => HashRef, default => sub {{}} );
sub clear_params { $_[0]->{_params} = {} }
sub has_params { my $self = shift; return scalar keys %{$self->{_params}}; }
sub params {
    my ( $self, $params ) = @_;
    if ( $params ) {
        $params = $self->munge_params($params);
        $self->{_params} = $params;
    }
    return $self->{_params};
}
has 'html_prefix' => ( is => 'rw' );
has 'use_defaults_over_obj' => ( is => 'rw', isa => Bool, default => 0 );
has 'use_init_obj_over_item' => ( is => 'rw', isa => Bool, default => 0 );


has 'form_meta_fields' => ( is => 'rw', isa => ArrayRef, default => sub {[]} );
has 'index' => ( is => 'rw', isa => ArrayRef );
sub add_to_index { my ( $self, $field_name, $field ) = @_; $self->{index}->{$field_name} = $field; }
sub form { shift }
sub is_form {1}
has 'ctx' => ( is => 'rw', weak_ref => 1 );
has 'init_object' => ( is => 'rw', isa => HashRef, default => sub {{}} );
sub clear_init_object { $_[0]->{init_object} = {} }
sub has_init_object { scalar keys %{$_[0]->{init_object}} }
has 'active' => ( is => 'rw', clearer => 'clear_active' );
sub full_name { '' }
sub full_accessor { '' }
sub fif { shift->fields_fif(@_) }

#========= Rendering ==========
has 'http_method'   => ( is  => 'ro', isa => Str, default => 'post' );
has 'action' => ( is => 'rw' );
#========= Errors ==========
has 'form_errors' => ( is => 'rw', isa => ArrayRef, default => sub {[]} );
sub clear_form_errors { $_[0]->{form_errors} = []; }
sub all_form_errors { my $self = shift; return @{$self->form_errors}; }
# TODO
sub add_form_error { }

sub errors {
    my $self         = shift;
    my @errors = $self->all_form_errors;
    push @errors,  map { $_->all_errors } $self->all_error_fields;
    return \@errors;
}
sub all_errors { my $self = shift; return @{$self->errors}; }
sub num_errors { my $self = shift; return scalar @{$self->errors}; }

#========= Messages ==========
has 'messages' => ( is => 'rw', isa => HashRef, builder => 'build_messages' );
sub build_messages {{}}
sub _get_form_message { my ($self, $msgname) = @_; return $self->messages->{$msgname}; }
sub _has_form_message { my ($self, $msgname) = @_; return exists $self->messages->{$msgname}; }
sub set_message { my ( $self, $msgname, $msg) = @_; $self->messages->{$msgname} = $msg; }
my $class_messages = {};
sub get_class_messages  {
    return $class_messages;
}
sub get_message {
    my ( $self, $msg ) = @_;
    return $self->_get_form_message($msg) if $self->_has_form_message($msg);
    return $self->get_class_messages->{$msg};
}
sub all_messages {
    my $self = shift;
    return { %{$self->get_class_messages}, %{$self->messages} };
}


#========= Methods ==========
sub BUILD {
    my $self = shift;
    $self->build_fields;
    $self->after_build_fields;
    $self->process unless $self->no_init_process;
}

sub process {
    my $self = shift;
    $self->clear if $self->processed;
    $self->setup(@_);
    $self->after_setup;
    $self->validate_form if $self->submitted;
    $self->processed(1);
    return $self->validated;
}

sub clear {
    my $self = shift;
    $self->clear_params;
    $self->clear_result;
    $self->clear_result_from;
    $self->submitted(undef);
    $self->item(undef);
    $self->clear_init_object;
    $self->ctx(undef);
    $self->processed(0);
    $self->ran_validation(0);

    # this will recursively clear field data
    $self->clear_data;
    $self->clear_form_errors;
    $self->clear_error_fields;
}

=head2 setup

This is where args passed to 'process' are set, and the form is
filled by params, object, or fields.

=cut

sub setup {
    my ( $self, @args ) = @_;
    if ( @args == 1 ) {
        $self->params( $args[0] );
    }
    elsif ( @args > 1 ) {
        my $hashref = {@args};
        while ( my ( $key, $value ) = each %{$hashref} ) {
            warn "invalid attribute '$key' passed to setup_form"
                unless $self->can($key);
            $self->$key($value);
        }
    }
    # set_active
    $self->in_setup;
    # update_fields

    # set the submitted flag
    $self->submitted(1) if ( $self->has_params && ! defined $self->submitted );

    # these fill the 'value' attributes
    if ( my $init_object = $self->use_init_obj_over_item ?
        ($self->init_object || $self->item) : ( $self->item || $self->init_object ) ) {
        $self->fill_from_object( $self->result, $init_object );
    }
    elsif ( !$self->submitted ) {
        # no initial object. empty form must be initialized
        $self->fill_from_fields( $self->result );
    }

    # fill in the input attribute
    my $params = clone( $self->params );
    if ( $self->submitted ) {
        $self->clear_result;
        my $result = $self->result;
        $self->fill_from_params( $result, $params, 1 );
    }

}

sub in_setup { }
sub after_setup { }
sub after_build_fields { }

sub update_model {
    my $self = shift;
}


sub munge_params {
    my ( $self, $params, $attr ) = @_;

    my $_fix_params = HTML::MuForm::Params->new;
    my $new_params = $_fix_params->expand_hash($params);
    if ( $self->html_prefix ) {
        $new_params = $new_params->{ $self->html_prefix };
    }
    $new_params = {} if !defined $new_params;
    return $new_params;
}

#====================================================================
# Validation
#====================================================================

sub validate_form {
    my $self = shift;

    $self->fields_validate;

    $self->validate;

    $self->validate_model;

    # 'validated' depends on no errors...

    $self->submitted(undef);
    $self->ran_validation(1);
}

# hook for child forms
sub validate {1}

# hook for model validation
sub validate_model {1}

sub validated { my $self = shift; return $self->ran_validation && ! $self->has_error_fields; }

sub get_default_value { }


1;
