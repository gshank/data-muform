package HTML::MuForm::Field::Select;
use Moo;
extends 'HTML::MuForm::Field';
use Types::Standard -types;


sub element_type { 'select' }

has 'options' => (
    is => 'rw',
    isa => ArrayRef,
    lazy => 1,
    builder => 'build_options',
);
sub build_options {[]}
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

sub clear_data {
    my $self = shift;
    $self->next::method();
    $self->reset_options_index;
}

sub field_validate {
    my $self = shift;
}

1;
