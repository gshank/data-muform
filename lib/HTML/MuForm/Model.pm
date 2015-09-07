package HTML::MuForm::Model;
use Moo::Role;

has 'item' => (
    is      => 'rw',
    lazy    => 1,
    builder => 'build_item',
    clearer => 'clear_item',
    trigger => sub { shift->set_item(@_) }
);
sub build_item { return }

sub set_item {
    my ( $self, $item ) = @_;
    $self->item_class( ref $item );
}

has 'item_id' => (
    is      => 'rw',
    clearer => 'clear_item_id',
    trigger => sub { shift->set_item_id(@_) }
);

sub set_item_id { }

has 'item_class' => (
#   isa => 'Str',
    is  => 'rw',
);

sub validate_model { }

sub clear_model { }

sub update_model { }

sub lookup_options { }

1;
