package Data::MuForm::Model::Object;
# ABSTRACT: stub for Object model

use Moo::Role;

sub update_model {
    my $self = shift;

    my $item = $self->item;
    return unless $item;
    foreach my $field ( $self->sorted_fields ) {
        my $name = $field->name;
        next unless $item->can($name);
        $item->$name( $field->value );
    }
}

1;
