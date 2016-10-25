package Data::MuForm::Meta;
# ABSTRACT: Meta magic to create 'has_fields'

=head1 NAME

Data::MuForm::Meta

=head1 SYNOPSIS

This file imports the 'has_field' sugar into the MuForm form and field
packages.

=cut

use Moo::_Utils;

sub import {
    my $class = shift;

    # the package into which we're importing
    my $target = caller;

    # local meta_fields to package, closed over by the 'around' methods
    my @_meta_fields;

    # has_field function which puts the field definitions into the local @_meta_fields
    my $has_field = sub {
        my ( $name, @options ) = @_;
        return unless $name;
        my $names = ( ref($name) eq 'ARRAY' ) ? $name : [ ($name) ];
        push @_meta_fields, { name => $_, @options } for @$names;
    };

    # function to insert 'around' modifiers into the calling package
    # install 'has_field' function into the calling package
    _install_coderef "${target}::has_field" => "MuMeta::has_field" => $has_field;

    # eval the basic functions into the caller package. It does not work to do these
    # with '_install_coderef' - C3 gets confused, and they could get cleaned away
    # 'maybe::next::method' necessary to get it to walk the tree
    # Note: _field_packages isn't actually used in MuForm code, but is left here
    # for possible diagnostic use. It will return an array of the packages
    # into which this code was imported.
    eval "package ${target};
        sub _meta_fields { shift->maybe::next::method(\@_) }
        sub _field_packages { shift->maybe::next::method(\@_) }";

    # get the 'around' function from the caller
    my $around = $target->can('around');
    # function to create the 'around' functions. Closes around @_meta_fields.
    my $apply_modifiers = sub {
        $around->(
            _meta_fields => sub {
                my ($orig, $self) = (shift, shift);
                return ($self->$orig(), @_meta_fields);
            }
        );
        $around->(
            _field_packages => sub {
                my ($orig, $self) = (shift, shift);
                my $package = $target;
                return ($self->$orig(), $package);
            }
        );
    };
    # actually install the around modifiers in the caller
    $apply_modifiers->();

}

1;
