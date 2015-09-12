package HTML::MuForm::Field::Integer;
# ABSTRACT: validate an integer value

use Moo;
use HTML::MuForm::Meta;
extends 'HTML::MuForm::Field::Text';

has '+size' => ( default => 8 );

our $class_messages = {
    'integer_needed' => 'Value must be an integer',
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

=head1 DESCRIPTION

This accepts a positive or negative integer.  Negative integers may
be prefixed with a dash.  By default a max of eight digits are accepted.
Widget type is 'text'.

If form has 'is_html5' flag active it will render <input type="number" ... />
instead of type="text"

The 'range_start' and 'range_end' attributes may be used to limit valid numbers.

=cut

1;
