package Data::MuForm::Field::Select;
use Moo;
extends 'Data::MuForm::Field';
use Types::Standard -types;
use HTML::Entities;

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
        die "Options array must contain an even number of elements"
            if @options % 2;
        my @opts;
        push @opts, { value => shift @options, label => shift @options } while @options;
        return \@opts;
    },
);
sub build_options {[]}
sub has_options { shift->num_options }
sub num_options { scalar @{$_[0]->options} }
has 'options_from' => ( isa => Str, is => 'rw', default => 'none' );
has 'do_not_reload' => ( isa => Bool, is => 'ro' );
has 'no_option_validation' => ( isa => Bool, is => 'rw' );

has 'options_index' => ( is => 'rw', isa => Num, default => 0 );
sub inc_options_index { $_[0]->{options_index}++; }
sub dec_options_index { $_[0]->{options_index}--; }
sub reset_options_index { $_[0]->{options_index} = 0; }

has 'multiple' => ( is => 'rw', isa => Bool, default => 0 );
has 'empty_select' => ( is => 'rw', isa => Str );
has '+input_without_param' => ( lazy => 1, builder => 'build_input_without_param' );
sub build_input_without_param {
    my $self = shift;
    if( $self->multiple ) {
        $self->not_nullable(1);
        return [];
    }
    return '';
}
has 'value_when_empty' => ( is => 'ro', lazy => 1, builder => 'build_value_when_empty' );
sub build_value_when_empty {
    my $self = shift;
    return [] if $self->multiple;
    return undef;
}


sub BUILD {
    my $self = shift;

    if( $self->options && $self->has_options ) {
        $self->options_from('build');
    }
    if( $self->form  && ! exists $self->{methods}->{build_options} ) {
        my $suffix = convert_full_name($self->full_name);
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
    $self->value($self->default)
        if( defined $self->default && not $self->has_value );
}

=comemnt
# this doesn't work (two different value attributes combined).
# TODO: look for better ways to arrayref a multiple value
before 'value' => sub {
    my $self  = shift;

    #return undef unless $self->has_result;
    my $value = $self->value;
    if( $self->multiple ) {
        if ( !defined $value || $value eq '' || ( ref $value eq 'ARRAY' && scalar @$value == 0 ) ) {
            $self->value( $self->value_when_empty );
        }
    }
};
=cut

sub clear_data {
    my $self = shift;
    $self->next::method();
    $self->reset_options_index;
}

sub field_validate {
    my $self = shift;
}

sub _load_options {
    my $self = shift;

    return
        if ( $self->options_from eq 'build' ||
        ( $self->has_options && $self->do_not_reload ) );
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

    # allow returning arrayref
    if ( ref $options[0] eq 'ARRAY' ) {
        @options = @{ $options[0] };
    }
    return unless @options;
    my $opts;
    # if options_<field_name> is returning an already constructed array of hashrefs
    if ( ref $options[0] eq 'HASH' ) {
        $opts = \@options;
    }
    else {
        warn "Options array must contain an even number of elements for field " . $self->name
            if @options % 2;
        push @{$opts}, { value => shift @options, label => shift @options } while @options;
    }
    if ($opts) {
        # sort options if sort method exists
        $opts = $self->sort_options($opts) if $self->methods->{sort};
        $self->options($opts);
    }
}

sub convert_full_name {
    my $full_name = shift;
    $full_name =~ s/\.\d+\./_/g;
    $full_name =~ s/\./_/g;
    return $full_name;
}

our $class_messages = {
    'select_not_multiple' => 'This field does not take multiple values',
    'select_invalid_value' => '\'{value}\' is not a valid value',
};

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


1;
