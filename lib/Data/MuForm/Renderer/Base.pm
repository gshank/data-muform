package Data::MuForm::Renderer::Base;
use Moo;

=head1 NAME

Data::MuForm::Renderer::Base

=head1 DESCRIPTION

Base functionality for renderers, including rendering standard form elements.

=cut

has 'localizer' => ( is => 'rw' );

has 'html_filter' => ( is => 'rw', default => sub { *default_html_filter } );

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

=head2 render_input

=cut

sub render_input {
  my ( $self, $rargs ) = @_;

  my $input_type = $rargs->{input_type};
  my $name = $rargs->{name};
  my $id = $rargs->{name};
  my $fif = $rargs->{fif};

  my $out = qq{<input type="$input_type" };
  $out .= qq{name="$name" };
  $out .= qq{id="$id" };
  $out .= qq{value="$fif" };
  $out .= $self->_render_attrs( $rargs->{element}, scalar @{$rargs->{errors}} );
  $out .= ">";
  return $out;
}

=head2 _render_attrs

=cut

sub _render_attrs {
  my ($self, $attrs, $has_errors) = @_;
  my $out = $self->_render_class( $attrs->{class}, $has_errors);
  while ( my ( $attr, $value ) =  each  %$attrs ) {
    next if $attr eq 'class';  # handled separately
    $out .= qq{$attr="$value" };
  }
  return $out;
}

=head2 _render_class

=cut

sub _render_class {
  my ( $self, $class, $has_errors ) = @_;

  $class ||= [];
  $class = [split(' ', $class)] unless ref $class eq 'ARRAY';
  push @$class, 'error' if $has_errors;
  my $classes = join(' ', @$class);
  my $out = qq{class="$classes" };
  return $out;
}

=head2 render_select

=cut

sub render_select {
  my ( $self, $rargs ) = @_;

  my $id = $rargs->{id};
  my $name = $rargs->{name};

  # beginning of select
  my $out = qq{<select };
  $out .= qq{name="$name" };
  $out .= qq{id="$id" };
  $out .= qq{multiple="multiple" } if $rargs->{multiple};
  $out .= $self->_render_attrs( $rargs->{element}, scalar @{$rargs->{errors}} );
  $out .= ">";

  # render empty_select
  if ( exists $rargs->{empty_select} ) {
    my $label = $self->localize($rargs->{empty_select});
    $out .= qq{\n<option value="">$label</option>};
  }

  # render options
  my $options = $rargs->{options};
  foreach my $option ( @$options ) {
    my $value = $option->{value};
    my $label = $option->{label};
    $out .= qq{<option value="$value">$label</option>};
  }

  # end of select
  $out .= "</select>\n";
  return $out;
}

=head2 render_checkbox

=cut

sub render_checkbox {
  my ( $self, $rargs ) = @_;

  my $name = $rargs->{name};
  my $id = $rargs->{name};
  my $checkbox_value = $rargs->{checkbox_value};
  my $fif = $rargs->{fif};

  my $out = qq{<checkbox };
  $out .= qq{name="$name" };
  $out .= qq{id="$id" };
  $out .= qq{value="$checkbox_value" };
  $out .= qq{checked="checked" } if $fif eq $checkbox_value;
  $out .= $self->_render_attrs( $rargs->{element}, scalar @{$rargs->{errors}} );
  $out .= ">";
  return $out;
}

=head2 render_textarea

=cut

sub render_textarea {
  my ( $self, $rargs ) = @_;

  my $name = $rargs->{name};
  my $id = $rargs->{id};
  my $fif = $rargs->{fif};

  my $out = "<textarea ";
  $out .= qq{name="$name" };
  $out .= qq{id="$id" };
  $out .= $self->_render_attrs( $rargs->{element}, scalar @{$rargs->{errors}} );
  $out .= ">$fif</textarea>";
  return $out;
}

=head2 render_element

=cut

sub render_element {
  my ( $self, $rargs ) = @_;

  my $form_element = $rargs->{form_element};
  my $meth = "render_$form_element";
  return $self->$meth($rargs);
}

=head2 render_label

=cut

sub render_label {
  my ( $self, $rargs ) = @_;

  my $id = $rargs->{id};
  my $label = $self->localize($rargs->{label});
  my $out = qq{<label for="$id">$label</label>};
  return $out
}

=head2 render_errors

=cut

sub render_errors {
  my ( $self, $rargs ) = @_;

  my $errors = $rargs->{errors} || [];
  my $out = '';
  foreach my $error (@$errors) {
    $out .= qq{<span>$error</span>};
  }
}

sub default_html_filter {
    my $string = shift;
    return '' if (!defined $string);
    $string =~ s/&/&amp;/g;
    $string =~ s/</&lt;/g;
    $string =~ s/>/&gt;/g;
    $string =~ s/"/&quot;/g;
    return $string;
}

1;
