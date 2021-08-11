package Data::MuForm::Model::Object;
# ABSTRACT: stub for Object model

use Moo::Role;

sub update_model {
    my $self = shift;

    my $model = $self->model;
    return unless $model;
    foreach my $field ( $self->all_sorted_fields ) {
        my $name = $field->name;
        next unless $model->can($name);
        $model->$name( $field->value );
    }
}

1;
