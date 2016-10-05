package Data::MuForm::Fields;
use Moo::Role;

use Types::Standard -types;
use Type::Utils;
use Data::Clone ('data_clone');
use Class::Load ('load_optional_class');
use Scalar::Util 'blessed';

=head2 NAME

Data::MuForm::Fields

=head2 DESCRIPTION

This role holds things that are common to Data::MuForm and compound fields.

Includes code that was split up into multiple roles in FormHandler: Fields,
BuildFields, InitResult.

=cut

has 'value' => ( is => 'rw', predicate => 'has_value', default => sub {{}} );
sub clear_value { $_[0]->{value} = {} }
sub values { $_[0]->value }
has 'init_value' => ( is => 'rw', clearer => 'clear_init_value' );
has 'input' => ( is => 'rw', clearer => 'clear_input' );
has 'filled_from' => ( is => 'rw', clearer => 'clear_filled_from' );

has 'meta_fields' => ( is => 'rw' );
has 'field_list' => ( is => 'rw', isa => ArrayRef, lazy => 1, builder => 'build_field_list' );
sub build_field_list {[]}
has 'fields' => ( is => 'rw', isa => ArrayRef, default => sub {[]});
sub add_field { my ( $self, @fields ) = @_; push @{$self->{fields}}, @fields; }
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
has 'field_namespace' => (
     is => 'rw',
     isa => ArrayRef,
     builder => 'build_field_namespace',
     coerce => sub {
         my $ns = shift;
         return [] unless defined $ns;
         return $ns if ref $ns eq 'ARRAY';
         return [$ns] if length($ns);
         return [];
     },
);
sub build_field_namespace { [] }

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
        grep { $_->is_active } $self->all_fields;
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

# Repeatable overrides this
sub fields_validate {
    my $self = shift;

    return unless $self->has_fields;
    # validate all fields
    my %value_hash;
    foreach my $field ( $self->all_sorted_fields ) {
        next if ( !$field->is_active || $field->disabled );
        # Validate each field and "inflate" input -> value.
        $field->validate_field;    # this calls the field's 'validate' routine
        $value_hash{ $field->accessor } = $field->value
            if ( $field->has_value && !$field->noupdate );
    }
    $self->value( \%value_hash );
}

sub fields_fif {
    my ( $self, $prefix ) = @_;

    $prefix ||= '';
    $prefix = $prefix . "."
        if ( $self->isa('Data::MuForm') && $self->html_prefix );

    my %params;
    foreach my $field ( $self->all_sorted_fields ) {
        next if ( ! $field->is_active || $field->password );
       #next unless $field->has_input || $field->has_value;
        my $fif = $field->fif;
        next if ( !defined $fif || (ref $fif eq 'ARRAY' && ! scalar @{$fif} ) );
        if ( $field->has_fields ) {
            my $next_params = $field->fields_fif( $prefix . $field->name . '.' );
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

sub fields_get_results {
    my $self = shift;

    my $result = $self->get_result;
    my @field_results;
    foreach my $field ( $self->all_sorted_fields ) {
        next if ! $field->is_active;
        my $result = $field->get_result;
        push @field_results, $result;
    }
    $result->{fields} = \@field_results;
    return $result;
}

#====================================================================
# Build Fields
#====================================================================

sub build_fields {
    my $self = shift;

    # process meta fields
    my @meta_fields = $self->_meta_fields;
    $self->meta_fields(\@meta_fields);
    my $meta_fields = data_clone(\@meta_fields);
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

    $fields = $self->clean_fields($fields);

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

has 'include' => ( is => 'rw', builder => 'build_include', lazy => 1 );
sub build_include { [] }
sub has_include {
    my $self = shift;
    my $include = $self->include || [];
    return scalar @{$include};
}

sub clean_fields {
    my ( $self, $fields ) = @_;
    if( $self->has_include ) {
        my @fields;
        my %include = map { $_ => 1 } @{ $self->include };
        foreach my $fld ( @$fields ) {
            push @fields, data_clone($fld) if exists $include{$fld->{name}};
        }
        return \@fields;
    }
    return data_clone( $fields );
};

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

    my $field_ns = $self->field_namespace;
    my @classes;
    # '+'-prefixed fields could be full namespaces
    if ( $type =~ s/^\+// ) {
        push @classes, $type;
    }
    foreach my $ns ( @$field_ns, 'Data::MuForm::Field' ) {
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
                unless $parent->isa('Data::MuForm::Field::Compound');
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
    #$field_attr->{localizer} = $parent->localizer;
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
    $field->form->add_repeatable_field($field)
        if ( $field->form && $field->is_repeatable);

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

sub _make_adhoc_field {
    my ( $self, $class, $field_attr ) = @_;

    # remove and save form & parent, because if the form class has a 'clone'
    # method, Data::Clone::clone will clone the form
    my $parent = delete $field_attr->{parent};
    my $form = delete $field_attr->{form};
#   $field_attr = $self->_merge_updates( $field_attr, $class );
    $field_attr->{parent} = $parent;
    $field_attr->{form} = $form;
    my $field = $self->new_field_with_roles( $class, $field_attr );
    return $field;
}


#====================================================================
# Initialize input/value (InitResult)
#====================================================================

# $input here is from the $params passed in on ->process
sub fill_from_params {
    my ( $self, $input, $exists ) = @_;

    $self->filled_from('params');
    return unless ( defined $input || $exists || $self->has_fields );
    # TODO - this will get replaced by setting the actual processed input 14 lines down.
    # Do we need this? Maybe could be used to transform input before processing?
    $self->transform_and_set_input($input);
    my $my_input = {};
    if ( ref $input eq 'HASH' ) {
        foreach my $field ( $self->all_sorted_fields ) {
            next if ! $field->is_active;
            my $fname = $field->input_param || $field->name;
            $field->fill_from_params($input->{$fname}, exists $input->{$fname});
            $my_input->{$fname} = $field->input if $field->has_input;
        }
    }
    # save input for this form or compound field. Used to determine whether really 'submitted'
    # in form. This should not be used for errors or fif or anything like that.
    $self->input( scalar keys %$my_input ? $my_input : {});
    return;
}

sub fill_from_object {
    my ( $self, $item ) = @_;

    return unless ( $item || $self->has_fields );    # empty fields for compounds
    $self->filled_from('object');
    my $my_value;
    my $init_obj;
    if ( $self->form &&
        $self->form->fill_from_object_source &&
        $self->form->fill_from_object_source eq 'item' &&
        $self->form->has_init_object ) {
        $init_obj = $self->form->init_object;
    }
    for my $field ( $self->all_sorted_fields ) {
        next if ! $field->is_active;
        if ( (ref $item eq 'HASH' && !exists $item->{ $field->accessor } ) ||
             ( blessed($item) && !$item->can($field->accessor) ) ) {
            my $found = 0;

            if ($init_obj) {
                # if we're using an item, look for accessor not found in item
                # in the init_object
                my @names = split( /\./, $field->full_name );
                my $init_obj_value = $self->find_sub_item( $init_obj, \@names );
                if ( defined $init_obj_value ) {
                    $found = 1;
                    $field->fill_from_object( $init_obj_value );
                }
            }

            $field->fill_from_fields() unless $found;
        }
        else {
           my $value = $self->_get_value( $field, $item ) unless $field->writeonly;
           $field->fill_from_object( $value );
        }
#       TODO: the following doesn't work for 'input_without_param' fields like checkboxes
#       $my_value->{ $field->name } = $field->value if $field->has_value;
        $my_value->{ $field->name } = $field->value;
    }
    $self->value($my_value);
    return;
}

# for when there are no params and no init_object
sub fill_from_fields {
    my ( $self ) = @_;

    $self->filled_from('fields');
    # defaults for compounds, etc.
    if ( my @values = $self->get_default_value ) {
        my $value = @values > 1 ? \@values : shift @values;
        if( ref $value eq 'HASH' || blessed $value ) {
            return $self->fill_from_object( $value );
        }
        if ( defined $value ) {
            $self->init_value($value);
            $self->value($value);
        }
    }
    my $my_value;
    for my $field ( $self->all_sorted_fields ) {
        next if (!$field->is_active);
        $field->fill_from_fields();
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
if ( $field->name eq 'foo' ) {
$DB::single=1;
}
    my $accessor = $field->accessor;
    my @values;
    if ( blessed($item) && $item->can($accessor) ) {
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
    if( $field->has_transform_default_to_value ) {
        @values = $field->transform_default_to_value->($field, @values);
    }
    my $value;
    # this is different than FH, I'm unsure why;
    # there was a problem with a default [1,3] ending up as [[1,3]]
    # in t/field_setup/default.t because of switching to getting
    # non-item defaults from init_object
    # used to be:
    #     if( $field->has_flag('multiple')) {
    #         $value = scalar @values == 1 && ! defined $values[0] ? [] : \@values;
    #     }
    # maybe because of 'transform_default_to_value'? But defaults have always been
    # able to be [1,3] for multiples. Accidentally worked before? Well, using
    # init_object for missing attributes was never tested well.
    if( $field->has_flag('multiple')) {
        if ( scalar @values == 1 && ! defined $values[0] ) {
            $value = [];
        }
        elsif ( scalar @values == 1 && ref $values[0] eq 'ARRAY' ) {
            $value = shift @values;
        }
        else {
            $value = \@values;
        }
    }
    else {
        $value = @values > 1 ? \@values : shift @values;
    }
    return $value;
}


sub fields_set_value {
    my $self = shift;
    my %value_hash;
    foreach my $field ( $self->all_fields ) {
        next if ! $field->is_active;
        $value_hash{ $field->accessor } = $field->value
            if ( $field->has_value && !$field->noupdate );
    }
    $self->value( \%value_hash );
}


sub clear_data {
    my $self = shift;
    $self->clear_input;
    $self->clear_value;
    # TODO - better way?
    $self->_clear_active unless $self->is_form;;
    $self->clear_error_fields;
    foreach my $field ( $self->all_fields ) {
        $field->clear_data;
    }
}

sub _install_methods {
    my $self = shift;
    foreach my $field ( $self->all_fields ) {
        next unless $field->form;
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
