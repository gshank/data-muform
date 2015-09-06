package HTML::MuForm::Fields;
use Moo::Role;

use Types::Standard -types;
use Data::Clone;
use Class::Load ('load_optional_class');

=head2 NAME

HTML::MuForm::Fields

=head2 DESCRIPTION

This role holes things that are common to HTML::MuForm and compound fields.

Includes code that was split up into multiple roles in FormHandler: Fields,
BuildFields, InitResult.

=cut

has 'value' => ( is => 'rw', clearer => 'clear_value', default => sub {{}} );
has 'input' => ( is => 'rw', clearer => 'clear_input' );
has 'result' => ( is => 'rw', isa => HashRef, clearer => 'clear_result', default => sub {{}} );

has 'field_list' => ( is => 'rw', isa => ArrayRef, lazy => 1, builder => 'build_field_list' );
sub build_field_list {[]}
has 'fields' => ( is => 'rw', isa => ArrayRef, default => sub {[]});
sub add_field { my ( $self, $field ) = @_; push @{$self->{fields}}, $field; }
sub clear_fields { my $self = shift; $self->{fields} = undef; }
sub all_fields { my $self = shift; return @{$self->{fields}}; }
sub set_field_at { my ( $self, $index, $field ) = @_; @{$self->{fields}}[$index] = $field; }
sub num_fields { my $self = shift; return scalar (@{$self->{fields}}); }
sub has_fields { my $self = shift; return scalar (@{$self->{fields}}); }
has 'error_fields' => ( is => 'rw', isa => ArrayRef, default => sub {[]} );
sub clear_error_fields { $_[0]->{error_fields} = [] }
sub has_error_fields { my $self = shift; return scalar @{$self->error_fields}; }
sub num_error_fields { my $self = shift; return scalar @{$self->error_fields}; }
sub add_error_field { my ($self, $field) = @_; push @{$self->error_fields}, $field; }
sub all_error_fields { my $self = shift; return @{$self->error_fields}; }

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

sub all_sorted_fields {
    my $self = shift;
    my @fields = sort { $a->order <=> $b->order }
        grep { $_->active } $self->all_fields;
    return @fields;
}

sub sorted_fields {
    my $self = shift;
    my @fields = $self->all_sorted_fields;
    return \@fields;
}

sub field_index {
    my ( $self, $name ) = @_;
    my $index = 0;
    for my $field ( $self->all_fields ) {
        return $index if $field->name eq $name;
        $index++;
    }
    return;
}

sub fields_validate {
    my $self = shift;

    return unless $self->has_fields;
    # validate all fields
    my %value_hash;
    foreach my $field ( $self->all_sorted_fields ) {
        next if ( !$field->active || $field->disabled );
        # Validate each field and "inflate" input -> value.
        $field->validate_field;    # this calls the field's 'validate' routine
        $value_hash{ $field->accessor } = $field->value
            if ( $field->has_value && !$field->noupdate );
    }
    $self->value( \%value_hash );
}

sub fields_fif {
    my ( $self, $result, $prefix ) = @_;

    $result ||= $self->result;
    $prefix ||= '';
    if ( $self->isa('HTML::MuForm') ) {
        $prefix = $self->html_prefix . "." if $self->html_prefix;
    }

    my %params;
    foreach my $field ( $self->all_sorted_fields ) {
        next if ( $field->is_inactive || $field->password );
        my $fif = $field->fif;
        next if ( !defined $fif || (ref $fif eq 'ARRAY' && ! scalar @{$fif} ) );
        if ( $field->has_fields ) {
            my $next_params = $field->fields_fif( $result,  $prefix . $field->name . '.' );
            next unless $next_params;
            %params = ( %params, %{$next_params} );
        }
        else {
            $params{ $prefix . $field->name } = $fif;
        }
    }
    return if !%params;
    return \%params;

}

#====================================================================
# Build Fields
#====================================================================

sub build_fields {
    my $self = shift;

    # process meta fields
    my $meta_fields = clone($self->_meta_fields);
    foreach my $mf ( @$meta_fields ) {
        my $field = $self->_make_field($mf);
    }

    # process field_list
    my $field_list = $self->field_list;
    foreach my $fl ( @$field_list ) {
        my $field = $self->_make_field($fl);
    }

    return unless $self->has_fields;
    $self->_order_fields;
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

    $self->form->add_to_index( $field->full_name => $field ) if $self->form;
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

sub _order_fields {
    my $self = shift;

    # get highest order number
    my $order = 0;
    foreach my $field ( $self->all_fields ) {
        $order++ if $field->order > $order;
    }
    $order++;
    # number all unordered fields
    foreach my $field ( $self->all_fields ) {
        $field->order($order) unless $field->order;
        $order++;
    }

}

#====================================================================
# Initialize input/value (InitResult)
#====================================================================

# How to handle repeatables and dynamic arrays of fields?
# maybe create a 'result' structure that contains 'nodes' of
# { input => '', value => '', errors => [] }. Hmm....
# Perhaps have special attribute replacements in Repeatable fields
# (simple compound fields should be okay)
# that identify the 'name' (foo.bar), the 'input', the 'value', the 'errors'
# from a hash:
#  $instances => {
#     'foo.bar' => { input => '', value => '', errors => [..] },
# }
# couldn't change other attributes, but you can't really do that
# with the current HFH functionality anyway. There is One Repeatable Field Def
# Of course, with a deeply nested structure, seems like you'd get into
# the weeds pretty quickly

# $input here is from the $params passed in on ->process
sub fill_from_params {
    my ( $self, $result, $input, $exists ) = @_;

    return unless ( defined $input || $exists || $self->has_fields );
    $self->input($input);
    if ( ref $input eq 'HASH' ) {
        foreach my $field ( $self->all_sorted_fields ) {
            next if ! $field->active;
            my $fname = $field->input_param || $field->name;
            $field->fill_from_params($result, $input->{$fname}, exists $input->{$fname});
        }
    }
    #$self->result($result);
}

sub fill_from_object {

}

sub fill_from_fields {
}

sub clear_data {
    my $self = shift;
    $self->clear_input;
    $self->clear_active;
    $_->clear_data for $self->all_fields;

}

1;
