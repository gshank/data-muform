package HTML::MuForm::Field::Integer;
# ABSTRACT: validate an integer value

use Moo;
use HTML::MuForm::Meta;
extends 'HTML::MuForm::Field::Text';

has '+size' => ( default => 8 );

has 'range_start' => ( is => 'rw' );
has 'range_end' => ( is => 'rw' );

our $class_messages = {
    'integer_needed' => 'Value must be an integer',
    'range_too_low'   => 'Value must be greater than or equal to [_1]',
    'range_too_high'  => 'Value must be less than or equal to [_1]',
    'range_incorrect' => 'Value must be between [_1] and [_2]',
};

sub get_class_messages {
    my $self = shift;
    return {
        %{ $self->next::method },
        %$class_messages,
    }
}

has '+base_apply' => ( default => sub {[
        {
            transform => sub {
                my $value = shift;
                $value =~ s/^\+//;
                return $value;
                }
        },
        {
            check => sub { $_[0] =~ /^-?[0-9]+$/ },
            message => sub {
                my ( $value, $field ) = @_;
                return $field->get_message('integer_needed');
            },
        }
    ]}
);

sub validate {
    my $field = shift;

    my $value = $field->value;
    return 1 unless defined $value;

    my $low  = $field->range_start;
    my $high = $field->range_end;

    if ( defined $low && defined $high ) {
        return
            $value >= $low && $value <= $high ? 1 :
              $field->add_error( $field->get_message('range_incorrect'), low => $low, high => $high );
    }

    if ( defined $low ) {
        return
            $value >= $low ? 1 :
              $field->add_error( $field->get_message('range_too_low'), low => $low );
    }

    if ( defined $high ) {
        return
            $value <= $high ? 1 :
              $field->add_error( $field->get_message('range_too_high'), high => $high );
    }

    return 1;
}


=head1 DESCRIPTION

This accepts a positive or negative integer.  Negative integers may
be prefixed with a dash.  By default a max of eight digits are accepted.
Widget type is 'text'.

If form has 'is_html5' flag active it will render <input type="number" ... />
instead of type="text"

The 'range_start' and 'range_end' attributes may be used to limit valid numbers.

=cut

1;
