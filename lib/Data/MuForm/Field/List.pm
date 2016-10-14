package Data::MuForm::Field::List;
use Moo;
extends 'Data::MuForm::Field';
use Types::Standard -types;

=head2 NAME

Data::MuForm::Field::List

=head2 DESCRIPTION

=cut

sub multiple {1}

# add trigger to 'value' so we can enforce arrayref value for multiple
has '+value' => ( trigger => 1 );
sub _trigger_value {
    my ( $self, $value ) = @_;
    if (!defined $value || $value eq ''){
        $value = [];
    }
    else {
       $value = ref $value eq 'ARRAY' ? $value : [$value];
    }
    $self->{value} = $value;
}

has '+input' => ( trigger => 1 );
sub _trigger_input {
    my ( $self, $input ) = @_;
    if (!defined $input || $input eq ''){
        $input = [];
    }
    else {
       $input = ref $input eq 'ARRAY' ? $input : [$input];
    }
    $self->{input} = $input;
}

has 'valid' => ( is => 'rw', isa => ArrayRef, default => sub {[]} );
sub has_valid {
   my $self = shift;
   return scalar @{$self->valid} ? 1 : 0;
}

sub base_validate {
    my $self = shift;

    if ( $self->has_valid ) {
        my %valid;
        @valid{@{$self->valid}} = ();
        foreach my $value ( @{$self->value} ) {
            unless ( exists $valid{$value} ) {
                $self->add_error("Invalid value: '{value}'", value => $value);
            }
        }
    }
}

1;
