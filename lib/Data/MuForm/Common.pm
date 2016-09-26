package Data::MuForm::Common;
use Moo::Role;

sub has_flag {
    my ( $self, $flag_name ) = @_;
    return unless $self->can($flag_name);
    return $self->$flag_name;
}

1;
