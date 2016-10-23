package Data::MuForm::Model;
# ABSTRACT: Base Model role

use Moo::Role;

has 'model' => (
    is      => 'rw',
    lazy    => 1,
    builder => 'build_model',
    clearer => 'clear_model',
    trigger => sub { shift->set_model(@_) }
);
sub build_model { return }

sub set_model {
    my ( $self, $model ) = @_;
    $self->model_class( ref $model );
}

has 'model_id' => (
    is      => 'rw',
    clearer => 'clear_model_id',
    trigger => sub { shift->set_model_id(@_) }
);

sub set_model_id { }

has 'model_class' => (
#   isa => 'Str',
    is  => 'rw',
);

sub use_model_for_defaults {1}

sub validate_model { }

sub update_model { }

sub lookup_options { }

1;
