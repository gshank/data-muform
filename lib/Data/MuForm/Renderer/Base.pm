package Data::MuForm::Renderer::Base;
use Moo;

=head1 NAME

Data::MuForm::Renderer::Base

=head1 DESCRIPTION

Base functionality for renderers, including rendering standard form elements.

=cut

has 'localizer' => ( is => 'rw' );

sub localize {
   my ( $self, @message ) = @_;
   return $self->localizer->loc_($message[0]);
}


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

  my $out = "<input type=\"$rargs->{input_type}\" ";
  $out .= qq{name="$rargs->{name}" };
  $out .= qq{id="$rargs->{id}" };
  $out .= qq{value="$rargs->{fif}" };
  $out .= $self->_render_attrs( $rargs->{element}, scalar @{$rargs->{errors}} );
  $out .= ">";
  return $out;
}

sub _render_attrs {
  my ($self, $attrs, $has_errors) = @_;
  my $out = $self->_render_class( $attrs->{class}, $has_errors);
  foreach my $attr ( keys %$attrs ) {
    next if $attr eq 'class';  # handled separately
    $out .= qq{$attr="$attrs->{$attr}" };
  }
  return $out;
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

  # beginning of select
  my $out = qq{<select };
  $out .= qq{name="$rargs->{name}" };
  $out .= qq{id="$rargs->{id}" };
  $out .= $self->_render_attrs( $rargs->{element}, scalar @{$rargs->{errors}} );
  $out .= ">";

  # render empty_select
  if ( exists $rargs->{empty_select} ) {
    my $label = $self->localize($rargs->{empty_select});
    $out .= qq{\n<option value="">$label</option>};
  }

  # end of select
  $out .= "</select>\n";
}

sub render_checkbox {
  my ( $self, $rargs ) = @_;

  my $out = qq{<checkbox };
  $out .= qq{name="$rargs->{name}" };
  $out .= qq{id="$rargs->{id}" };
  $out .= qq{multiple="multiple" } if $rargs->{multiple};
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
