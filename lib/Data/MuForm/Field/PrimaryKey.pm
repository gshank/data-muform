package Data::MuForm::Field::PrimaryKey;
# ABSTRACT: primary key field

use Moo;
extends 'Data::MuForm::Field';
use Types::Standard -types;

=head1 SYNOPSIS

This field is for providing the primary key for Repeatable fields:

   has_field 'addresses' => ( type => 'Repeatable' );
   has_field 'addresses.address_id' => ( type => 'PrimaryKey' );

Do not use this field to hold the primary key of the form's main db object (item).
That primary key is in the 'item_id' attribute.

=cut

has 'is_primary_key' => ( isa => Bool, is => 'ro', default => '1' );
has '+no_value_if_empty' => ( default => 1 );

sub BUILD {
    my $self = shift;
    if ( $self->has_parent ) {
        if ( $self->parent->has_primary_key ) {
            push @{ $self->parent->primary_key }, $self;
        }
        else {
            $self->parent->primary_key( [ $self ] );
        }
    }
}

1;
