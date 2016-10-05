package Data::MuForm::Renderer::Base;
use Moo;

sub render {
    my $self = shift;
}

sub render_field {
  my ( $self, $rargs ) = @_;

  my $rendered;
  my $form_element = $self->render_element($rargs);
}

sub render_input {
  my ( $self, $rargs ) = @_;

  my $out = qq{<input type="$rargs->{input_type}" };
  $out .= qq{name="$rargs->{name}" };
  $out .= qq{id="$rargs->{id}" };
  $out .= qq{value="$rargs->{fif}" };
  my $attrs = $rargs->{element};
  foreach my $attr ( keys %$attrs ) {
    $out .= qq{$attr="$attrs->{$attr}" };
  }
  $out .= ">";
}

sub render_select {
  my ( $self, $rargs ) = @_;

  my $out = "<select ";
  $out .= ">";
}

sub render_checkbox {
  my ( $self, $rargs ) = @_;

  my $out = "<checkbox ";
  $out .= ">";
}

sub render_textarea {
  my ( $self, $rargs ) = @_;

  my $out = "<textarea ";
  $out .= ">";
}

sub render_element {
  my ( $self, $rargs ) = @_;

  my $form_element = $rargs->{form_element};
  my $meth = "render_$form_element";
  return $self->$meth($rargs);
}


1;
