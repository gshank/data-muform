package HTML::MuForm::Renderer::Base;
use Moo;

sub render {
    my $self = shift;
}

sub render_field {
  my ( $self, $rargs ) = @_;

  my $rendered;
  my $form_element = $rargs->{form_element};
  if ( $form_element eq 'input' ) {
    $rendered = $self->render_input($rargs);
  }
  elsif ( $form_element eq 'select' ) {
    $rendered = $self->render_select($rargs);
  }
  elsif ( $form_element eq 'checkbox' ) {
    $rendered = $self->render_checkbox($rargs);
  }
  elsif ( $form_element eq 'textarea' ) {
    $rendered = $self->render_textarea($rargs);
  }
  else {
    $rendered = $self->render_generic($rargs);
  }
}

sub render_input {
  my ( $self, $rargs ) = @_;
}

sub render_select {
  my ( $self, $rargs ) = @_;
}

sub render_checkbox {
  my ( $self, $rargs ) = @_;
}

sub render_textarea {
  my ( $self, $rargs ) = @_;
}

sub render_generic {
  my ( $self, $rargs ) = @_;
}

1;
