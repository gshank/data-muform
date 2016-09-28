package Data::MuForm::Field::Currency;
# ABSTRACT: US currency-like values

use Moo;
extends 'Data::MuForm::Field::Text';

has '+html5_type_attr' => ( default => 'number' );
has 'currency_symbol' => (
    is      => 'ro',
    default => '$',
);
has 'disallow_commas' => (
    is      => 'ro',
    default => 0,
);

our $class_messages = {
    'currency_convert' => 'Cannot be converted to currency',
    'currency_real'    => 'Must be a real number',
};

sub get_class_messages  {
    my $self = shift;
    return {
        %{ $self->next::method },
        %$class_messages,
    }
}

has '+base_apply' => ( default => sub {
    [   {   # remove any leading currency symbol
            transform => sub {
                my ( $value, $field ) = @_;
                my $c = $field->currency_symbol;
                $value =~ s/^\Q$c\E// if $c;
                return $value;
            },
        },
        {   # check number looks real, optionally allow comma digit groupings
            check => sub {
                my ( $value, $field ) = @_;
                return $field->disallow_commas
                     ? $value =~ /^[-+]?\d+(?:\.\d+)?$/
                     : $value =~ /^[-+]?(?:\d+|\d{1,3}(,\d{3})*)(?:\.\d+)?$/;
            },
            message => sub {
                my ( $value, $field ) = @_;
                return [ $field->get_message('currency_real'), $value ];
            },
        },
        {   # remove commas
            transform => sub {
                my ($value, $field) = @_;
                $value =~ tr/,//d unless $field->disallow_commas;
                return $value;
            },
        },
        {   # convert to standard number, formatted to 2 decimal palaces
            transform => sub { sprintf '%.2f', $_[0] },
            message   => sub {
                my ( $value, $field ) = @_;
                return [ $field->get_message('currency_convert'), $value ];
            },
        },
    ]
});


=head1 DESCRIPTION

Validates that a positive or negative real value is entered.
Formatted with two decimal places.

Uses a period for the decimal point.

If form has 'is_html5' flag active it will render <input type="number" ... />
instead of type="text"


=head1 ATTRIBUTES

=head2

=over

=item currency_symbol

Currency symbol to remove from start of input if found, default is dollar
C<$>.

=item disallow_commas

Don't Allow commas in input for digit grouping? Digits are grouped into groups of 3,
for example C<1,000,000,000>. Defaults to I<false>.

=back

=cut

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
