package Data::MuForm::Field::URL;
# ABSTRACT: URL field
use Moo;
extends 'Data::MuForm::Field::Text';
use Regexp::Common ('URI');

=head1 NAME

Data::MuForm::Field::URL

=head1 DESCRIPTION

A URL field;

=cut

our $class_messages = {
    'invalid_url' => 'Invalid URL',
};

sub get_class_messages  {
    my $self = shift;
    return {
        %{ $self->next::method },
        %$class_messages,
    }
}

sub validate {
  my ($self, $value) = @_;
  unless ( $value =~ qr/^$RE{URI}{HTTP}{-scheme => "https?"}$/ ) {
    $self->add_error($self->get_message('invalid_url'));
  }
}

1;
