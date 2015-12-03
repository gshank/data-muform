package HTML::MuForm::Field::Textarea;
# ABSTRACT: textarea input

use Moo;
extends 'HTML::MuForm::Field::Text';
use Types::Standard -types;

sub build_form_element { 'textarea' }

has 'cols'    => ( isa => Int, is => 'rw' );
has 'rows'    => ( isa => Int, is => 'rw' );

=head1 Summary

For HTML textarea

=cut

1;
