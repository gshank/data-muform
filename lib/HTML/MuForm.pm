package HTML::MuForm;
use Moo;
use HTML::MuForm::Meta;

with 'HTML::MuForm::Fields';

use Types::Standard -types;
use Class::Load ('load_optional_class');
use Data::Clone;
use HTML::MuForm::Params;

has 'name' => ( is => 'rw', isa => Str, builder => 'build_name');
sub build_name {
    my $self = shift;
    return ref $self;
}
has 'http_method'   => ( is  => 'ro', isa => Str, default => 'post' );
has 'action' => ( is => 'rw' );
has 'submitted' => ( is => 'rw', default => undef );  # three values: 0, 1, undef
has 'processed' => ( is => 'rw', default => 0 );
has 'validated' => ( is => 'rw', default => 0 );
has 'ran_validation' => ( is => 'rw', default => 0 );
has '_params' => ( is => 'rw', isa => HashRef );
sub has_params { my $self = shift; return scalar keys %{$self->{_params}}; }
sub params {
    my ( $self, $params ) = @_;
    if ( $params ) {
        $params = $self->munge_params($params);
        $self->{_params} = $params;
    }
    return $self->{_params};
}
has 'value' => ( is => 'rw' );
has 'html_prefix' => ( is => 'rw' );

has 'field_name_space' => ( is => 'rw', isa => ArrayRef, builder => 'build_field_name_space' );
sub build_field_name_space { [] }
has 'index' => ( is => 'rw', isa => ArrayRef );
sub add_to_index { my ( $self, $field_name, $field ) = @_; $self->{index}->{$field_name} = $field; }
sub form { shift }
has 'item' => ( is => 'rw' );
has 'ctx' => ( is => 'rw', weak_ref => 1 );


has 'init_object' => ( is => 'rw' );

sub BUILD {
    my $self = shift;
    $self->build_fields;
}

sub process {
    my $self = shift;
    $self->clear if $self->processed;
    $self->setup(@_);
    $self->validate_form if $self->submitted;
}

sub clear {
    my $self = shift;
    $self->params({});
    $self->submitted(undef);
    $self->item(undef);
    $self->init_object(undef);
    $self->ctx(undef);
    $self->processed(0);
}

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
    # update_fields

    # set the submitted flag
    $self->submitted(1) if ( $self->has_params && ! defined $self->submitted );
}

sub update_model {
    my $self = shift;
}


sub field {
    my ( $self, $name, $die, $f ) = @_;

    my $index;
    # if this is a full_name for a compound field
    # walk through the fields to get to it
    return undef unless ( defined $name );
    if( $self->form && $self == $self->form &&
        exists $self->index->{$name} ) {
        return $self->index->{$name};
    }
    if ( $name =~ /\./ ) {
        my @names = split /\./, $name;
        $f ||= $self->form || $self;
        foreach my $fname (@names) {
            $f = $f->field($fname);
            return unless $f;
        }
        return $f;
    }
    else    # not a compound name
    {
        for my $field ( $self->all_fields ) {
            return $field if ( $field->name eq $name );
        }
    }
    return unless $die;
    die "Field '$name' not found in '$self'";
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



1;
