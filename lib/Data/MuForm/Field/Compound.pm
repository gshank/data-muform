package Data::MuForm::Field::Compound;
# ABSTRACT: field consisting of subfields

use Moo;
extends 'Data::MuForm::Field';
with 'Data::MuForm::Fields';
use Data::MuForm::Meta;
use Types::Standard ('Bool', 'ArrayRef');

=head1 SYNOPSIS

This field class is designed as the base (parent) class for fields with
multiple subfields. Examples are L<HTML::FormHandler::Field::DateTime>
and L<HTML::FormHandler::Field::Duration>.

A compound parent class requires the use of sub-fields prepended
with the parent class name plus a dot

   has_field 'birthdate' => ( type => 'DateTime' );
   has_field 'birthdate.year' => ( type => 'Year' );
   has_field 'birthdate.month' => ( type => 'Month' );
   has_field 'birthdate.day' => ( type => 'MonthDay');

If all validation is performed in the parent class so that no
validation is necessary in the child classes, then the field class
'Nested' may be used.

The array of subfields is available in the 'fields' array in
the compound field:

   $form->field('birthdate')->fields

Error messages will be available in the field on which the error
occurred. You can access 'error_fields' on the form or on Compound
fields (and subclasses, like Repeatable).

The process method of this field runs the process methods on the child fields
and then builds a hash of these fields values.  This hash is available for
further processing by L<HTML::FormHandler::Field/actions> and the validate method.

=head2 widget

Widget type is 'compound'

=head2 build_update_subfields

You can set 'defaults' or other settings in a 'build_update_subfields' method,
which contains attribute settings that will be merged with field definitions
when the fields are built. Use the 'by_flag' key with 'repeatable', 'compound',
and 'contains' subkeys, or use the 'all' key for settings which apply to all
subfields in the compound field.

=cut

sub is_compound {1}
has 'obj' => ( is => 'rw', clearer => 'clear_obj' );
has 'primary_key' => ( is => 'rw', isa => ArrayRef,
    predicate => 'has_primary_key', );

has '+field_namespace' => (
    default => sub {
        my $self = shift;
        return $self->form->field_namespace
            if $self->form && $self->form->field_namespace;
        return [];
    },
);

sub BUILD {
    my $self = shift;
    $self->build_fields;
}

# this is for testing compound fields outside
# of a form
sub test_validate_field {
    my $self = shift;
    unless( $self->form ) {
        if( $self->has_input ) {
            $self->fill_from_params( $self->input );
        }
        else {
            $self->fill_from_fields();
        }
    }
    $self->validate_field;
    unless( $self->form ) {
        foreach my $err_fld (@{$self->error_fields}) {
            $self->push_errors($err_fld->all_errors);
        }
    }
}

around 'fill_from_object' => sub {
    my $orig = shift;
    my $self = shift;
    my ( $obj ) = @_;
    $self->obj($obj) if $obj;
    $self->$orig(@_);
};

after 'clear_data' => sub {
    my $self = shift;
    $self->clear_obj;
};

around 'fill_from_params' => sub {
    my $orig = shift;
    my $self = shift;
    my ( $input, $exists ) = @_;
    if ( !$input && !$exists ) {
        return $self->fill_from_fields();
    }
    else {
        return $self->$orig(@_);
    }
};

sub render {
  my ( $self, $rargs ) = @_;
  my $render_args = $self->get_render_args(%$rargs);
  return $self->renderer->render_compound($render_args, $self->fields);
}


1;
