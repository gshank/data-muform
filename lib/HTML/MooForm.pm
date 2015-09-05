package HTML::MooForm;

use HTML::MooForm::Meta;

sub BUILD {
    my $self = shift;
    $self->build_fields;
}

sub build_fields {
    my $self = shift;
}

sub process {
    my $self = shift;
}

has 'fields' => (
    is => 'rw',
);

1;
