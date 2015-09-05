package HTML::MooForm::Meta;

use Moo::Role;
use Moo::_Utils;
use Import::Into;

sub import {
    my $target = caller;
    my $class = shift;

   _install_coderef "${target}::has_field" => "HTML::MooForm::Meta::has_field" => \&has_field;
   _install_coderef "${target}::_meta_fields" => "HTML::MooForm::Meta::_meta_fields" => \&_meta_fields;
}

our @_meta_fields;

sub has_field {
    my ( $name, @options ) = @_;
    return unless $name;
    push @_meta_fields, { name => $name, @options };
}

sub _meta_fields {
    return \@_meta_fields;
}

1;
