package Data::MuForm::Field::RequestToken;
# ABSTRACT: anti-CSRF token field

use Moo;
extends 'Data::MuForm::Field::Text';
use Types::Standard -types;

our $class_messages = {
    'token_failed' => 'Form submission failed. Please try again.',
};


sub get_class_messages  {
    my $self = shift;
    return {
        %{ $self->next::method },
        %$class_messages,
    }
}

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
