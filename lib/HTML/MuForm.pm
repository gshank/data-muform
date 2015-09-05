package HTML::MuForm;
use Moo;
with 'HTML::MuForm::Meta';

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
has 'fields' => ( is => 'rw', isa => ArrayRef, default => sub {[]});
sub add_field { my ( $self, $field ) = @_; push @{$self->{fields}}, $field; }
sub clear_fields { my $self = shift; $self->{fields} = undef; }
sub all_fields { my $self = shift; return @{$self->{fields}}; }
sub set_field_at { my ( $self, $index, $field ) = @_; @{$self->{fields}}[$index] = $field; }
sub num_fields { my $self = shift; return scalar (@{$self->{fields}}); }
sub has_fields { my $self = shift; return scalar (@{$self->{fields}}); }
has 'error_fields' => ( is => 'rw', isa => ArrayRef );
has 'index' => ( is => 'rw', isa => ArrayRef );
sub add_to_index { my ( $self, $field_name, $field ) = @_; $self->{index}->{$field_name} = $field; }
sub field_index {
    my ( $self, $name ) = @_;
    my $index = 0;
    for my $field ( $self->all_fields ) {
        return $index if $field->name eq $name;
        $index++;
    }
    return;
}
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

#====================================================================
# Build Fields
#====================================================================

sub build_fields {
    my $self = shift;
    my $meta_fields = clone($self->_meta_fields);

    my $index = 0;
    foreach my $mf ( @$meta_fields ) {
        my $field = $self->_make_field($mf);
        $index++;
    }
}

sub _make_field {
    my ( $self, $field_attr ) = @_;

    my $type = $field_attr->{type} ||= 'Text';
    my $name = $field_attr->{name};

    # check for a field prefixed with '+', that overrides
    my $do_update;
    if ( $name =~ /^\+(.*)/ ) {
        $field_attr->{name} = $name = $1;
        $do_update = 1;
    }

    my $class = $self->_find_field_class( $type, $name );

    my $parent = $self->_find_parent( $field_attr );

    my $field = $self->_update_or_create( $parent, $field_attr, $class, $do_update );
}

sub _find_field_class {
    my ( $self, $type, $name ) = @_;

    my $field_ns = $self->field_name_space;
    my @classes;
    # '+'-prefixed fields could be full namespaces
    if ( $type =~ s/^\+// ) {
        push @classes, $type;
    }
    foreach my $ns ( @$field_ns, 'HTML::MuForm::Field' ) {
        push @classes, $ns . "::" . $type;
    }
    # look for Field in possible namespaces
    my $class;
    foreach my $try ( @classes ) {
        last if $class = load_optional_class($try) ? $try : undef;
    }
    die "Could not load field class '$type' for field '$name'"
       unless $class;

    return $class;
}


sub _find_parent {
    my ( $self, $field_attr ) = @_;

    # parent and name correction for names with dots
    my $parent;
    if ( $field_attr->{name} =~ /\./ ) {
        my @names       = split /\./, $field_attr->{name};
        my $simple_name = pop @names;
        my $parent_name = join '.', @names;
        # use special 'field' method call that starts from
        # $self, because names aren't always starting from
        # the form
        $parent      = $self->field($parent_name, undef, $self);
        if ($parent) {
            die "The parent of field " . $field_attr->{name} . " is not a Compound Field"
                unless $parent->isa('HTML::MuForm::Field::Compound');
            $field_attr->{name}   = $simple_name;
        }
        else {
            die "did not find parent for field " . $field_attr->{name};
        }
    }
    elsif ( !( $self->form && $self == $self->form ) ) {
        # set parent
        $parent = $self;
    }

    # get full_name
    my $full_name = $field_attr->{name};
    $full_name = $parent->full_name . "." . $field_attr->{name}
        if $parent;
    $field_attr->{full_name} = $full_name;
    return $parent;

}


sub _update_or_create {
    my ( $self, $parent, $field_attr, $class, $do_update ) = @_;

    $parent ||= $self->form;
    $field_attr->{parent} = $parent;
    $field_attr->{form} = $self->form if $self->form;
    my $index = $parent->field_index( $field_attr->{name} );
    my $field;
    if ( defined $index ) {
        if ($do_update)    # this field started with '+'. Update.
        {
            $field = $parent->field( $field_attr->{name} );
            die "Field to update for " . $field_attr->{name} . " not found"
                unless $field;
            foreach my $key ( keys %{$field_attr} ) {
                next if $key eq 'name' || $key eq 'form' || $key eq 'parent' ||
                    $key eq 'full_name' || $key eq 'type';
                $field->$key( $field_attr->{$key} )
                    if $field->can($key);
            }
        }
        else               # replace existing field
        {
            $field = $self->new_field_with_roles( $class, $field_attr);
            $parent->set_field_at( $index, $field );
        }
    }
    else                   # new field
    {
        $field = $self->new_field_with_roles( $class, $field_attr);
        $parent->add_field($field);
    }
    return $field;
}

sub new_field_with_roles {
    my ( $self, $class, $field_attr ) = @_;
    # not handling roles yet
    my $field = $class->new(%$field_attr);
    return $field;
}

#====================================================================
# End Build Fields
#====================================================================

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

    $self->submitted(undef);
    $self->ran_validation(1);
}

# hook for child forms
sub validate {1}

# hook for model validation
sub validate_model {1}

sub fields_validate {
    my $self = shift;

    return unless $self->has_fields;
    # validate all fields
    my %value_hash;
    foreach my $field ( $self->all_fields ) {
        next if ( !$field->active || $field->disabled );
        # Validate each field and "inflate" input -> value.
        $field->validate_field;    # this calls the field's 'validate' routine
        $value_hash{ $field->accessor } = $field->value
            if ( $field->has_value && !$field->noupdate );
    }
    $self->value( \%value_hash );
}


1;
