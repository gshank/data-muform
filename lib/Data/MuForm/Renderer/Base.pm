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
  $out .= $self->_render_class( $attrs->{class}, scalar @{$rargs->{errors}} );
  foreach my $attr ( keys %$attrs ) {
    next if $attr eq 'class';  # handled separately
    $out .= qq{$attr="$attrs->{$attr}" };
  }
  $out .= ">";
}

sub _render_class {
  my ( $self, $class, $has_errors ) = @_;

  $class ||= [];
  $class = [split(' ', $class)] unless ref $class eq 'ARRAY';
  push @$class, 'error' if $has_errors;
  my $classes = join(' ', @$class);
  my $out = qq{class="$classes" };
  return $out;
}


sub render_select {
  my ( $self, $rargs ) = @_;

  my $out = qq{<select };
  $out .= qq{name="$rargs->{name}" };
  $out .= qq{id="$rargs->{id}" };
  $out .= ">";
}

sub render_checkbox {
  my ( $self, $rargs ) = @_;

  my $out = "<checkbox ";
  $out .= qq{name="$rargs->{name}" };
  $out .= qq{id="$rargs->{id}" };
  $out .= ">";
}

sub render_textarea {
  my ( $self, $rargs ) = @_;

  my $out = "<textarea ";
  $out .= qq{name="$rargs->{name}" };
  $out .= qq{id="$rargs->{id}" };
  $out .= ">";
}

sub render_element {
  my ( $self, $rargs ) = @_;

  my $form_element = $rargs->{form_element};
  my $meth = "render_$form_element";
  return $self->$meth($rargs);
}


1;
