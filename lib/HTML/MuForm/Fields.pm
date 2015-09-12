package HTML::MuForm::Fields;
use Moo::Role;

use Types::Standard -types;
use Data::Clone;
use Class::Load ('load_optional_class');
use Scalar::Util 'blessed';

=head2 NAME

HTML::MuForm::Fields

=head2 DESCRIPTION

This role holds things that are common to HTML::MuForm and compound fields.

Includes code that was split up into multiple roles in FormHandler: Fields,
BuildFields, InitResult.

=cut

has 'value' => ( is => 'rw', predicate => 'has_value', default => sub {{}} );
sub clear_value { $_[0]->{value} = {} }
sub values { $_[0]->value }
has 'init_value' => ( is => 'rw', clearer => 'clear_init_value' );
has 'input' => ( is => 'rw', clearer => 'clear_input' );
has 'result' => ( is => 'rw', isa => HashRef, default => sub {{}} );
sub clear_result { $_[0]->{result} = {} }
has 'result_from' => ( is => 'rw', clearer => 'clear_result_from' );

has 'meta_fields' => ( is => 'rw' );
has 'field_list' => ( is => 'rw', isa => ArrayRef, lazy => 1, builder => 'build_field_list' );
sub build_field_list {[]}
#has 'saved_meta_fields' => ( is => 'rw', isa => ArrayRef, default => sub {[]} );
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
has 'field_name_space' => ( is => 'rw', isa => ArrayRef, builder => 'build_field_name_space' );
sub build_field_name_space { [] }

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
    $prefix = $prefix . "."
        if ( $self->isa('HTML::MuForm') && $self->html_prefix );

    my %params;
    foreach my $field ( $self->all_sorted_fields ) {
        next if ( ! $field->active || $field->password );
        next unless $field->has_input || $field->has_value;
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
    my @meta_fields = $self->_meta_fields;
    $self->meta_fields(\@meta_fields);
    my $meta_fields = clone(\@meta_fields);
    $self->process_field_array( $meta_fields );

    # process field_list
    my $field_list = $self->field_list;
    $self->process_field_array ( $field_list );

    return unless $self->has_fields;
    $self->_order_fields;
    $self->_install_methods;
}

sub process_field_array {
    my ( $self, $fields ) = @_;

    # TODO: there's got to be a better way of doing this
    my $num_fields   = scalar @$fields;
    my $num_dots     = 0;
    my $count_fields = 0;
    while ( $count_fields < $num_fields ) {
        foreach my $field (@$fields) {
            my $count = ( $field->{name} =~ tr/\.// );
            next unless $count == $num_dots;
            $self->_make_field($field);
            $count_fields++;
        }
        $num_dots++;
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
        if ($do_update) {  # this field started with '+'. Update.
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
        else { # replace existing field
            $field = $self->new_field_with_roles( $class, $field_attr);
            $parent->set_field_at( $index, $field );
        }
    }
    else { # new field
        $field = $self->new_field_with_roles( $class, $field_attr);
        $parent->add_field($field);
    }
    return $field;
}

sub new_field_with_roles {
    my ( $self, $class, $field_attr ) = @_;
    # not handling roles
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

    $self->result_from('params');
    return unless ( defined $input || $exists || $self->has_fields );
    $self->input($input);
    if ( ref $input eq 'HASH' ) {
        foreach my $field ( $self->all_sorted_fields ) {
            next if ! $field->active;
            my $fname = $field->input_param || $field->name;
            $field->fill_from_params($result, $input->{$fname}, exists $input->{$fname});
        }
    }
    return;
}

sub fill_from_object {
    my ( $self, $result, $item ) = @_;

    return unless ( $item || $self->has_fields );    # empty fields for compounds
    $self->result_from('object');
    my $my_value;
    my $init_obj = $self->form->init_object;
    for my $field ( $self->all_sorted_fields ) {
        next if ! $field->active;
        if ( (ref $item eq 'HASH' && !exists $item->{ $field->accessor } ) ||
             ( blessed($item) && !$item->can($field->accessor) ) ) {
            my $found = 0;
            if (1) {  # do by default for now
                # if we're using an item, look for accessor not found in item
                # in the init_object
                my @names = split( /\./, $field->full_name );
                my $init_obj_value = $self->find_sub_item( $init_obj, \@names );
                if ( defined $init_obj_value ) {
                    $found = 1;
                    $field->fill_from_object( $result, $init_obj_value );
                }
            }
            $result = $field->fill_from_fields($result) unless $found;
        }
        else {
           my $value = $self->_get_value( $field, $item ) unless $field->writeonly;
           $field->fill_from_object( $result, $value );
        }
        $my_value->{ $field->name } = $field->value;
    }
    $self->value($my_value);
    return;
}

# for when there are no params and no init_object
sub fill_from_fields {
    my ( $self, $result ) = @_;

    $self->result_from('fields');
    # defaults for compounds, etc.
    if ( my @values = $self->get_default_value ) {
        my $value = @values > 1 ? \@values : shift @values;
        if( ref $value eq 'HASH' || blessed $value ) {
            return $self->fill_from_object( $result, $value );
        }
        if ( defined $value ) {
            $self->init_value($value);
            $self->value($value);
        }
    }
    my $my_value;
    for my $field ( $self->all_sorted_fields ) {
        next if (!$field->active);
        $field->fill_from_fields($result);
        $my_value->{ $field->name } = $field->value if $field->has_value;
    }
    # setting value here to handle disabled compound fields, where we want to
    # preserve the 'value' because the fields aren't submitted...except for the
    # form. Not sure it's the best idea to skip for form, but it maintains previous behavior
    $self->value($my_value) if ( keys %$my_value );
    return;
}

sub find_sub_item {
    my ( $self, $item, $field_name_array ) = @_;
    my $this_fname = shift @$field_name_array;;
    my $field = $self->field($this_fname);
    my $new_item = $self->_get_value( $field, $item );
    if ( scalar @$field_name_array ) {
        $new_item = $field->find_sub_item( $new_item, $field_name_array );
    }
    return $new_item;
}



sub _get_value {
    my ( $self, $field, $item ) = @_;

    my $accessor = $field->accessor;
    my @values;
    if( $field->form && $field->form->use_defaults_over_obj && ( @values = $field->get_default_value )  ) {
    }
    elsif ( blessed($item) && $item->can($accessor) ) {
        # this must be an array, so that DBIx::Class relations are arrays not resultsets
        @values = $item->$accessor;
        # for non-DBIC blessed object where access returns arrayref
        if ( scalar @values == 1 && ref $values[0] eq 'ARRAY' && $field->has_flag('multiple') ) {
            @values = @{$values[0]};
        }
    }
    elsif ( exists $item->{$accessor} ) {
        my $v = $item->{$accessor};
        if($field->has_flag('multiple') && ref($v) eq 'ARRAY'){
            @values = @$v;
        } else {
            @values = $v;
        }
    }
    elsif ( @values = $field->get_default_value ) {
    }
    else {
        return;
    }
    # TODO
#   if( $field->has_inflate_default_method ) {
#       @values = $field->inflate_default(@values);
#   }
    my $value;
    if( $field->has_flag('multiple')) {
        $value = scalar @values == 1 && ! defined $values[0] ? [] : \@values;
    }
    else {
        $value = @values > 1 ? \@values : shift @values;
    }
    return $value;
}

sub clear_data {
    my $self = shift;
    $self->clear_input;
    $self->clear_value;
#   $self->clear_activate;
    $self->clear_error_fields;
    foreach my $field ( $self->all_fields ) {
        $field->clear_data;
    }
}

sub _install_methods {
    my $self = shift;
    foreach my $field ( $self->all_fields ) {
        my $suffix = convert_full_name($field->full_name);
        foreach my $prefix ( 'validate', 'default' ) {
            my $meth_name = "${prefix}_$suffix";
            if ( my $meth = $self->form->can($meth_name) ) {
                my $wrap_sub = sub {
                    my $self = shift;
                    return $self->form->$meth;
                };
                $field->{methods}->{$prefix} = $wrap_sub;
            }
        }
    }
}

sub convert_full_name {
    my $full_name = shift;
    $full_name =~ s/\.\d+\./_/g;
    $full_name =~ s/\./_/g;
    return $full_name;
}


1;
