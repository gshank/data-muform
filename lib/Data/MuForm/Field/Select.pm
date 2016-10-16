package Data::MuForm::Field::Select;
# ABSTRACT: Select field

use Moo;
extends 'Data::MuForm::Field';
use Types::Standard -types;
use HTML::Entities;
use Data::Dump ('pp');

sub build_form_element { 'select' }

has 'options' => (
    is => 'rw',
    isa => ArrayRef,
    lazy => 1,
    builder => 'build_options',
    coerce => sub {
        my $options = shift;
        my @options = @$options;
        return [] unless scalar @options;
        return \@options if ref $options[0] eq 'HASH';
        my @opts;
        if ( scalar @options == 1 && ref($options[0]) eq 'ARRAY' ) {
            @options = @{ $options[0] };
            push @opts, { value => $_, label => $_ } foreach @options;
        }
        else {
            die "Options array must contain an even number of elements"
              if @options % 2;
            push @opts, { value => shift @options, label => shift @options } while @options;
        }
        return \@opts;
    },
);
sub build_options {[]}
sub has_options { shift->num_options }
sub num_options { scalar @{$_[0]->options} }
sub all_options { @{$_[0]->options} }
has 'options_from' => ( isa => Str, is => 'rw', default => 'none' );
has 'do_not_reload' => ( isa => Bool, is => 'ro' );
has 'no_option_validation' => ( isa => Bool, is => 'rw' );

has 'multiple' => ( is => 'ro', isa => Bool, default => 0 );
has 'empty_select' => ( is => 'rw', isa => Str, predicate => 'has_empty_select' );

# add trigger to 'value' so we can enforce arrayref value for multiple
has '+value' => ( trigger => 1 );
sub _trigger_value {
    my ( $self, $value ) = @_;
    return unless $self->multiple;
    if (!defined $value || $value eq ''){
        $value = [];
    }
    else {
       $value = ref $value eq 'ARRAY' ? $value : [$value];
    }
    $self->{value} = $value;
}

# This is necessary because if a Select field is unselected, no param will be
# submitted. Needs to be lazy because it checks 'multiple'. Needs to be vivified in BUILD.
has '+input_without_param' => ( lazy => 1, builder => 'build_input_without_param' );
sub build_input_without_param {
    my $self = shift;
    if( $self->multiple ) {
        $self->not_nullable(1);
        return [];
    }
    else {
        return '';
    }
}

has 'label_column' => ( is => 'rw', default => 'name' );
has 'active_column' => ( is => 'rw', default => 'active' );
has 'sort_column' => ( is => 'rw' );


sub BUILD {
    my $self = shift;

    # vivify, so predicate works
    $self->input_without_param;

    if( $self->options && $self->has_options ) {
        $self->options_from('build');
    }
    if( $self->form  && ! exists $self->{methods}->{build_options} ) {
        my $suffix = $self->convert_full_name($self->full_name);
        my $meth_name = "options_$suffix";
        if ( my $meth = $self->form->can($meth_name) ) {
            my $wrap_sub = sub {
                my $self = shift;
                return $self->form->$meth;
            };
            $self->{methods}->{build_options} = $wrap_sub;
        }
    }
    $self->_load_options unless $self->has_options;
}

sub fill_from_params {
    my ( $self, $input, $exists ) = @_;
    $input = ref $input eq 'ARRAY' ? $input : [$input]
        if $self->multiple;
    $self->next::method( $input, $exists );
    $self->_load_options;
}

sub fill_from_object {
    my ( $self, $obj ) = @_;
    $self->next::method( $obj );
    $self->_load_options;
}

sub fill_from_field {
    my ( $self ) = @_;
    $self->next::method();
    $self->_load_options;
}

sub _load_options {
    my $self = shift;

    return
        if ( $self->options_from eq 'build' ||
        ( $self->has_options && $self->do_not_reload ) );

    # we allow returning an array instead of an arrayref from a build method
    # and it's the usual thing from the DBIC model
    my @options;
    if( my $meth = $self->get_method('build_options') ) {
        @options = $meth->($self);
        $self->options_from('method');
    }
    elsif ( $self->form ) {
        my $full_accessor;
        $full_accessor = $self->parent->full_accessor if $self->parent;
        @options = $self->form->lookup_options( $self, $full_accessor );
        $self->options_from('model') if scalar @options;
    }
    return unless @options;    # so if there isn't an options method and no options
                               # from a table, already set options attributes stays put

    # possibilities:
    #  @options = ( 1 => 'one', 2 => 'two' );
    #  @options = ([ 1 => 'one', 2 => 'tw' ]);
    #  @options = ([ { value => 1, label => 'one'}, { value => 2, label => 'two'}]);
    #  @options = ([[ 'one', 'two' ]]);
    my $opts = ref $options[0] ? $options[0] : \@options;;
    $opts = $self->options($opts);  # coerce will re-format

    if (scalar @$opts) {
        # sort options if sort method exists
        $opts = $self->sort_options($opts) if $self->methods->{sort};
        $self->options($opts);
    }
}

our $class_messages = {
    'select_not_multiple' => 'This field does not take multiple values',
    'select_invalid_value' => '\'{value}\' is not a valid value',
};

sub base_render_args {
    my $self = shift;
    my $args = $self->next::method(@_);
    $args->{multiple} = $self->multiple;
    $args->{options} = $self->options;
    $args->{empty_select} = $self->empty_select if $self->has_empty_select;
    return $args;
}


sub get_class_messages  {
    my $self = shift;
    return {
        %{ $self->next::method },
        %$class_messages,
    }
}

sub base_validate {
    my ($self) = @_;

    my $value = $self->value;
    return unless defined $value;    # nothing to check

    if ( ref $value eq 'ARRAY' &&
        !( $self->can('multiple') && $self->multiple ) )
    {
        $self->add_error( $self->get_message('select_not_multiple') );
        return;
    }
    elsif ( ref $value ne 'ARRAY' && $self->multiple ) {
        $value = [$value];
        $self->value($value);
    }

    return if $self->no_option_validation;

    # create a lookup hash
    my %options;
    foreach my $opt ( @{ $self->options } ) {
        if ( exists $opt->{group} ) {
            foreach my $group_opt ( @{ $opt->{options} } ) {
                $options{$group_opt->{value}} = 1;
            }
        }
        else {
            $options{$opt->{value}} = 1;
        }
    }
    for my $value ( ref $value eq 'ARRAY' ? @$value : ($value) ) {
        unless ( $options{$value} ) {
            my $opt_value = encode_entities($value);
            $self->add_error($self->get_message('select_invalid_value'), value => $opt_value);
            return;
        }
    }
    return 1;
}

sub as_label {
    my ( $self, $value ) = @_;

    $value = $self->value unless defined $value;
    return unless defined $value;
    if ( $self->multiple ) {
        unless ( ref($value) eq 'ARRAY' ) {
            if( $self->has_transform_default_to_value ) {
                my @values = $self->transform_default_to_value->($self, $value);
                $value = \@values;
            }
            else {
                # not sure under what circumstances this would happen, but
                # just in case
                return $value;
            }
        }
        my @labels;
        my %value_hash;
        @value_hash{@$value} = ();
        for ( $self->all_options ) {
            if ( exists $value_hash{$_->{value}} ) {
                push @labels, $_->{label};
                delete $value_hash{$_->{value}};
                last unless keys %value_hash;
            }
        }
        my $str = join(', ', @labels);
        return $str;
    }
    else {
        for ( $self->all_options ) {
            return $_->{label} if $_->{value} eq $value;
        }
    }
    return;
}

1;
