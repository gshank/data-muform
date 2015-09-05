package HTML::MooForm;

use Moo;
with 'HTML::MooForm::Meta';

has 'name' => ( is => 'rw', builder => 'build_name');
sub build_name {
    my $self = shift;
    return ref $self;
}
has 'http_method'   => ( is  => 'ro', default => 'post' );
has 'action' => ( is => 'rw' );
has 'submitted' => ( is => 'rw', default => 0 );
has 'params' => ( is => 'rw' );
has 'fields' => (
    is => 'rw',
);
has 'error_fields' => ( is => 'rw' );

has 'init_object' => ( is => 'rw' );

sub BUILD {
    my $self = shift;
    $self->build_fields;
}

sub build_fields {
    my $self = shift;
    my $meta_fields = $self->_meta_fields;

}

sub process {
    my $self = shift;
}

sub setup {
    my $self = shift;
}

sub validate_form {
    my $self = shift;
}

sub update_model {
    my $self = shift;
}

1;
