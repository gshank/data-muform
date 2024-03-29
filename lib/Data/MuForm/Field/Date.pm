package Data::MuForm::Field::Date;
# ABSTRACT: a date field with formats

use Moo;
extends 'Data::MuForm::Field::Text';
use DateTime;
use DateTime::Format::Strptime;
use Scalar::Util ('blessed');

=head1 SUMMARY

This field may be used with the jQuery Datepicker plugin.

You can specify the format for the date using jQuery formatDate strings
or DateTime strftime formats. (Default format is format => '%Y-%m-%d'.)

   d  - "%e" - day of month (no leading zero)
   dd - "%d" - day of month (two digit)
   o  - "%{day_of_year}" - day of the year (no leading zeros)
   oo - "%j" - day of the year (three digit)
   D  - "%a" - day name short
   DD - "%A" - day name long
   m  - "%{day_of_month}" - month of year (no leading zero)
   mm - "%m" - month of year (two digit) "%m"
   M  - "%b" - month name short
   MM - "%B" - month name long
   y  - "%y" - year (two digit)
   yy - "%Y" - year (four digit)
   @  - "%s" - Unix timestamp (ms since 01/01/1970)

For example:

   has_field 'start_date' => ( type => 'Date', format => "dd/mm/y" );

or

   has_field 'start_date' => ( type => 'Date', format => "%d/%m/%y" );

You can also set 'date_end' and 'date_start' attributes for validation
of the date range. Use iso_8601 formats for these dates ("yyyy-mm-dd");

   has_field 'start_date' => ( type => 'Date', date_start => "2009-12-25" );

Customize error messages 'date_early' and 'date_late':

   has_field 'start_date' => ( type => 'Date,
       messages => { date_early => 'Pick a later date',
                     date_late  => 'Pick an earlier date', } );

=head2 Using with HTML5

If the field's form has its 'is_html5' flag active, then the field's rendering
behavior changes in two ways:

=over

=item *

It will render as <input type="date" ... /> instead of type="text".

=item *

If the field's format is set to anything other than ISO date format
(%Y-%m-%d), then attempting to render the field will result in a warning.

(Note that the default value for the field's format attribute is, in fact,
the ISO date format.)

=back

=cut

has '+html5_input_type' => ( default => 'date' );
has 'format' => ( is => 'rw', default => "%Y-%m-%d" );
has 'locale'     => ( is => 'rw' );
has 'time_zone'  => ( is => 'rw' );
has 'date_start' => ( is => 'rw', clearer => 'clear_date_start' );
has 'date_end'   => ( is => 'rw', clearer => 'clear_date_end' );
has '+size' => ( default => '10' );
has '+transform_value_to_fif' => ( default => sub { *date_deflate } );

# translator for Datepicker formats to DateTime strftime formats
my $dp_to_dt = {
    "d"  => "\%e",    # day of month (no leading zero)
    "dd" => "\%1",    # day of month (2 digits) "%d"
    "o"  => "\%4",    # day of year (no leading zero) "%{day_of_year}"
    "oo" => "\%j",    # day of year (3 digits)
    "D"  => "\%a",    # day name long
    "DD" => "\%A",    # day name short
    "m"  => "\%5",    # month of year (no leading zero) "%{day_of_month}"
    "mm" => "\%3",    # month of year (two digits) "%m"
    "M"  => "\%b",    # Month name short
    "MM" => "\%B",    # Month name long
    "y"  => "\%2",    # year (2 digits) "%y"
    "yy" => "\%Y",    # year (4 digits)
    "@"  => "\%s",    # epoch
};

our $class_messages = {
    'date_early' => 'Date is too early',
    'date_late' => 'Date is too late',
};
sub get_class_messages  {
    my $self = shift;
    return {
        %{ $self->next::method },
        %$class_messages,
    }
}

sub date_deflate {
    my ( $self, $value ) = @_;

    # if not a DateTime, assume correctly formatted string and return
    return $value unless blessed $value && $value->isa('DateTime');
    my $format = $self->get_strf_format;
    my $string = $value->strftime($format);
    return $string;
}

sub validate {
    my $self = shift;

    my $format = $self->get_strf_format;
    my @options;
    push @options, ( time_zone => $self->time_zone ) if $self->time_zone;
    push @options, ( locale => $self->locale ) if $self->locale;
    my $strp = DateTime::Format::Strptime->new( pattern => $format, @options );

    my $dt = eval { $strp->parse_datetime( $self->value ) };
    unless ($dt) {
        $self->add_error( $strp->errmsg || $@ );
        return;
    }
    $self->value($dt);
    my $val_strp = DateTime::Format::Strptime->new( pattern => "%Y-%m-%d", @options );
    if ( $self->date_start ) {
        my $date_start = $val_strp->parse_datetime( $self->date_start );
        die "date_start: " . $val_strp->errmsg unless $date_start;
        my $cmp = DateTime->compare( $date_start, $dt );
        $self->add_error($self->get_message('date_early')) if $cmp eq 1;
    }
    if ( $self->date_end ) {
        my $date_end = $val_strp->parse_datetime( $self->date_end );
        die "date_end: " . $val_strp->errmsg unless $date_end;
        my $cmp = DateTime->compare( $date_end, $dt );
        $self->add_error($self->get_message('date_late')) if $cmp eq -1;
    }
}

sub get_strf_format {
    my $self = shift;

    # if contains %, then it's a strftime format
    return $self->format if $self->format =~ /\%/;
    my $format = $self->format;
    foreach my $dpf ( reverse sort keys %{$dp_to_dt} ) {
        my $strf = $dp_to_dt->{$dpf};
        $format =~ s/$dpf/$strf/g;
    }
    $format     =~ s/\%1/\%d/g,
        $format =~ s/\%2/\%y/g,
        $format =~ s/\%3/\%m/g,
        $format =~ s/\%4/\%{day_of_year}/g,
        $format =~ s/\%5/\%{day_of_month}/g,
        return $format;
}

1;
