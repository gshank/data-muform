package Data::MuForm::Renderer::Base;
# ABSTRACT: Renderer

use Moo;
use List::Util ('any');

=head1 NAME

Data::MuForm::Renderer::Base

=head1 DESCRIPTION

Base functionality for renderers, including rendering standard form elements.

=cut

has 'form' => ( is => 'ro' );

has 'localizer' => ( is => 'ro' );

has 'layouts' => ( is => 'rw', builder => 'build_layouts' );

has 'wrappers' => ( is => 'rw', builder => 'build_wrappers' );

has 'default_field_layout' => ( is => 'rw', default => 'standard' );

has 'default_field_wrapper' => ( is => 'rw', default => 'simple' );

has 'default_wrapper_tag' => ( is => 'rw', default => 'div' );

has 'default_cb_layout' => ( is => 'rw', default => 'cbwrll' );

has 'default_rd_layout' => ( is => 'rw', default => 'labels_right' );

has 'default_error_tag' => ( is => 'rw', default => 'span' );

sub render_hook {
    my $self = shift;
    return $self->form->render_hook($self, @_);
}


sub localize {
   my ( $self, @message ) = @_;
   return $self->localizer->loc_($message[0]);
}

#==============================
#  Forms
#==============================

sub render_form {
    my ($self, $rargs, $fields ) = @_;

    my $out = '';
    $out .= $self->render_start($rargs);
    $out .= $self->render_form_errors($rargs);

    foreach my $field ( @$fields ) {
        $out .= $field->render;
    }

    $out .= $self->render_end($rargs);
    return $out;
}

sub render_start {
    my ($self, $rargs ) = @_;

    my $name = $rargs->{name};
    my $method = $rargs->{method};
    my $out = qq{<form };
    $out .= qq{id="$name" };
    $out .= qq{method="$method" };
    $out .= q{>};
}

sub render_end {
    my ($self, $rargs ) = @_;

   return q{</form>};
}

sub render_form_errors {
    my ( $self, $rargs ) = @_;
    my $out = '';
    if ( scalar @{$rargs->{form_errors}} ) {
        $out .= q{<div class="form_errors>};
        foreach my $error ( @{$rargs->{form_errors}} ) {
            $out .= qq{<span>$error</span>};
        }
        $out .= q{</div>};
    }
    return $out;
}

#==============================
#  Fields
#==============================

sub render_field {
  my ( $self, $rargs ) = @_;

  $rargs->{rendering} = 'field';
  $self->render_hook($rargs);

  # render the field layout
  my $layout = $rargs->{layout} || $self->default_field_layout;
  my $layout_meth = $self->layouts->{$layout};
  die "layout method '$layout' not found" unless $layout_meth;
  my $out = '';
  $out .= $layout_meth->($self, $rargs);

  return $self->wrap_field($rargs, $out);
}

sub wrap_field {
  my ( $self, $rargs, $out ) = @_;

  # wrap the field
  my $wrapper = $rargs->{wrapper} || $self->default_field_wrapper;
  return $out if $wrapper eq 'none';
  my $wrapper_meth = $self->wrappers->{$wrapper};
  die "wrapper method '$wrapper' not found" unless $wrapper_meth;
  $out = $wrapper_meth->($self, $rargs, $out);
  return $out;
}

sub render_compound {
    my ( $self, $rargs, $fields ) = @_;

    my $out = '';
    foreach my $field ( @$fields ) {
        $out .= $field->render;
    }
    # don't always wrap? what should be standard
    if ( $rargs->{wrapper} ) {
        $out = $self->wrap_field($rargs, $out);
    }
    return $out;
}

sub render_repeatable {
    my ( $self, $rargs, $fields ) = @_;
    my $out = '';
    foreach my $field ( @$fields ) {
        my $id = $field->id . '.inst';
        $out .= qq{\n<div class="repinst" id="$id">};
        $out .= $field->render;
        $out .= qq{</div>};
    }
    $out = $self->wrap_field($rargs, $out);
    return $out;
}

#==============================
#  Utility methods
#==============================

sub add_to_class {
  my ( $href, $class ) = @_;

  return unless defined $class;
  if ( exists $href->{class} && ref $href->{class} ne 'ARRAY' ) {
     my @classes = split(' ', $href->{class});
     $href->{class} = \@classes;
  }
  if ( $class && ref $class eq 'ARRAY' ) {
     push @{$href->{class}}, @$class;
  }
  else {
      push @{$href->{class}}, $class;
  }
}

=head2 process_attrs

=cut

sub process_attrs {
    my ($attrs, $skip) = @_;

    $skip ||= [];
    my @use_attrs;
    my %skip;
    @skip{@$skip} = ();
    for my $attr( sort keys %$attrs ) {
        next if exists $skip{$attr};
        my $value = '';
        if( defined $attrs->{$attr} ) {
            if( ref $attrs->{$attr} eq 'ARRAY' ) {
                # we don't want class="" if no classes specified
                next unless scalar @{$attrs->{$attr}};
                $value = join (' ', @{$attrs->{$attr}} );
            }
            else {
                $value = $attrs->{$attr};
            }
        }
        if ( $value =~ /[&"<>]/ ) {
            $value = html_filter($value);
        }
        push @use_attrs, sprintf( '%s="%s"', $attr, $value );
    }
    my $out = join( ' ', @use_attrs );
    return $out;
}

#==============================
#  Field form elements
#==============================

=head2 render_input

=cut

sub render_input {
  my ( $self, $rargs ) = @_;

  my $input_type = $rargs->{input_type};
  # checkboxes are special
  return $self->render_checkbox($rargs) if $input_type eq 'checkbox';

  my $name = $rargs->{name};
  my $id = $rargs->{id};
  my $fif = html_filter($rargs->{fif});

  my $out = qq{\n<input type="$input_type" };
  $out .= qq{name="$name" };
  $out .= qq{id="$id" };
  $out .= qq{value="$fif" };
  add_to_class( $rargs->{element_attr}, 'error' ) if @{$rargs->{errors}};
  $out .= process_attrs($rargs->{element_attr});
  $out .= "/>";
  return $out;
}

=head2 render_select

=cut

sub render_select {
  my ( $self, $rargs ) = @_;

  my $id = $rargs->{id};
  my $name = $rargs->{name};

  # beginning of select
  my $out = qq{\n<select };
  $out .= qq{name="$name" };
  $out .= qq{id="$id" };
  $out .= qq{multiple="multiple" } if $rargs->{multiple};
  add_to_class( $rargs->{element_attr}, 'error' ) if @{$rargs->{errors}};
  $out .= process_attrs($rargs->{element_attr});
  $out .= ">";

  # render empty_select
  if ( exists $rargs->{empty_select} ) {
    my $label = $self->localize($rargs->{empty_select});
    $out .= qq{\n<option value="">$label</option>};
  }

  # render options
  my $options = $rargs->{options};
  foreach my $option ( @$options ) {
    my $label = $self->localize($option->{label});
    $out .= qq{\n<option };
    $out .= process_attrs($option, ['label']);
    $out .= qq{>$label</option>};
  }

  # end of select
  $out .= "\n</select>\n";
  return $out;
}


=head2 render_textarea

=cut

sub render_textarea {
  my ( $self, $rargs ) = @_;

  my $name = $rargs->{name};
  my $id = $rargs->{id};
  my $fif = html_filter($rargs->{fif});

  my $out = "\n<textarea ";
  $out .= qq{name="$name" };
  $out .= qq{id="$id" };
  add_to_class( $rargs->{element_attr}, 'error' ) if @{$rargs->{errors}};
  $out .= process_attrs($rargs->{element_attr});
  $out .= ">$fif</textarea>";
  return $out;
}

=head2 render_element

=cut

sub render_element {
  my ( $self, $rargs ) = @_;

  $rargs->{rendering} = 'element';
  $self->render_hook($rargs);
  my $form_element = $rargs->{form_element};
  my $meth = "render_$form_element";
  return $self->$meth($rargs);
}

=head2 render_label

=cut

sub render_label {
  my ( $self, $rargs, $left_of_label, $right_of_label ) = @_;

  $rargs->{rendering} = 'label';
  $self->render_hook($rargs);
  $right_of_label ||= '';
  $left_of_label ||= '';

  my $id = $rargs->{id};
  my $label = $self->localize($rargs->{label});
  my $out = qq{\n<label };
  $out .= qq{for="$id"};
  $out .= process_attrs($rargs->{label_attr});
  $out .= qq{>};
  $out .= qq{$left_of_label$label$right_of_label};
  $out .= qq{</label>};
  return $out
}

=head2 render_errors

=cut

sub render_errors {
  my ( $self, $rargs ) = @_;

  $rargs->{rendering} = 'errors';
  $self->render_hook($rargs);
  my $errors = $rargs->{errors} || [];
  my $out = '';
  my $tag = $rargs->{error_tag} || $self->default_error_tag;
  foreach my $error (@$errors) {
    $out .= qq{\n<$tag>$error</$tag>};
  }
  return $out;
}

sub html_filter {
    my $string = shift;
    return '' if (!defined $string);
    $string =~ s/&/&amp;/g;
    $string =~ s/</&lt;/g;
    $string =~ s/>/&gt;/g;
    $string =~ s/"/&quot;/g;
    return $string;
}


#==============================
#  Radio, Radiogroup
#==============================

sub render_layout_radiogroup {
  my ( $self, $rargs ) = @_;

  my $label_layout = $rargs->{rd_layout} || $self->default_rd_layout;

  my $out = $self->render_label($rargs);
  # render options
  my $options = $rargs->{options};
  foreach my $option ( @$options ) {
    my $rd_element = $self->render_radio_option($rargs, $option);
    my $rd_elements = $label_layout eq 'labels_left' ? ['', $rd_element] : [$rd_element, ''];
    $out .= $self->render_radio_label($rargs, $option, @$rd_elements);
  }
  return $out;
}

sub render_radio_option {
    my ( $self, $rargs, $option ) = @_;

    my $name = $rargs->{name};
    my $out = qq{<input type="radio" };
    $out .= qq{name="$name" };
    $out .= process_attrs($option, ['label']);
    if ( $rargs->{fif} eq $option->{value} ) {
        $out .= qq{checked="checked" };
    }
    $out .= q{/>};
}

sub render_radio_label {
  my ( $self, $rargs, $option, $left_of_label, $right_of_label ) = @_;

  $right_of_label ||= '';
  $left_of_label ||= '';
  my $label = $self->localize($option->{label});

  my $attrs = { class => ['radio'] };
  $attrs->{for} = $option->{id} if $option->{id};
  add_to_class( $attrs, $rargs->{radio_label_class} );

  my $out = qq{\n<label };
  $out.= process_attrs($attrs);
  $out .= q{>};
  $out .= qq{$left_of_label$label$right_of_label};
  $out .= qq{</label>};
}

#==============================
#  Checkboxes
#==============================

sub render_layout_checkbox {
    my ( $self, $rargs) = @_;

  my $cb_element = $self->render_checkbox($rargs);
  my $cb_layout = $rargs->{cb_layout} || $self->default_cb_layout;
  my $out = '';
  if ( my $meth = $self->can($cb_layout) ) {
     $out = $meth->($self, $rargs, $cb_element);
  }
  else {
    die "Checkbox layout '$cb_layout' not found";
  }
  $out .= $self->render_errors($rargs);

  return $out;

}

=head2 render_checkbox

=cut

sub render_checkbox {
  my ( $self, $rargs ) = @_;

  my $name = $rargs->{name};
  my $id = $rargs->{name};
  my $checkbox_value = $rargs->{checkbox_value};
  my $fif = html_filter($rargs->{fif});

  my $out = qq{<input };
  $out .= qq{type="checkbox" };
  $out .= qq{name="$name" };
  $out .= qq{id="$id" };
  $out .= qq{value="$checkbox_value" };
  $out .= qq{checked="checked" } if $fif eq $checkbox_value;
  add_to_class( $rargs->{element_attr}, 'error' ) if @{$rargs->{errors}};
  $out .= process_attrs($rargs->{element_attr});
  $out .= "/>";
  return $out;
}

=head2 cbwrll

Checkbox, wrapped, label left

   <label class="checkbox" for="option1"><input id="option1" name="option1" type="checkbox" value="1" /> Option1 </label>

=cut

sub cbwrll {
  my ( $self, $rargs, $cb_element ) = @_;

  my $out = $self->render_label($rargs, '', $cb_element);
  return $out

}

=head2 cbwrlr

Checkbox wrapped, label right

=cut

sub cbwrlr {
  my ( $self, $rargs, $cb_element ) = @_;

  my $out = $self->render_label($rargs, $cb_element, '' );
  return $out;
}

=head2 cbnowrll

Checkbox not wrapped, label left

=cut

sub cbnowrll {
  my ( $self, $rargs, $cb_element ) = @_;

  my $out = $self->render_label($rargs);
  $out .= $cb_element;
  return $out;
}

sub cb2l {
  my ( $self, $rargs, $cb_element ) = @_;

  my $out = $self->render_label($rargs);

  my $id = $rargs->{id};
  my $option_label = $self->localize($rargs->{option_label}) || '';
  $out .= qq{\n<label for="$id">$cb_element$option_label</label>};
  return $out;
}

#==============================
#  Layouts
#==============================

sub build_layouts {
    my $self = shift;
    my $layouts = {
        standard => *layout_standard,
        no_label => *layout_no_label,
    };
    return $layouts;
}

sub layout_standard {
    my ( $self, $rargs ) = @_;

    my $form_element = $rargs->{form_element};
    my $input_type = $rargs->{input_type};

    if ( $form_element eq 'input' && $input_type eq 'checkbox' ) {
       return $self->render_layout_checkbox($rargs);
    }
    elsif ( $form_element eq 'radiogroup' ) {
       return $self->render_layout_radiogroup($rargs);
    }
    elsif ( $form_element eq 'input' &&  any { $input_type eq $_ } ('submit', 'reset', 'hidden' )) {
       return $self->render_element($rargs);
    }
    else {
       return $self->render_layout_standard($rargs);
    }
}

sub render_layout_standard {
    my ( $self, $rargs ) = @_;

    my $out = '';
    $out .= $self->render_label($rargs);
    $out .= $self->render_element($rargs);
    $out .= $self->render_errors($rargs);
    return $out;
}

sub layout_no_label {
    my ( $self, $rargs ) = @_;
    my $out = '';
    $out .= $self->render_element($rargs);
    $out .= $self->render_errors($rargs);
    return $out;
}

#==============================
#  Wrappers
#==============================

sub build_wrappers {
    my $self = shift;
    my $wrappers = {
        simple => *wrapper_simple,
        fieldset => *wrapper_fieldset,
   };
   return $wrappers;
}

sub wrapper_simple {
    my ( $self, $rargs, $rendered ) = @_;

    my $tag = $rargs->{wrapper_attr}{tag} || $self->default_wrapper_tag;
    my $out = qq{\n<$tag };
    $out .= process_attrs($rargs->{wrapper_attr}, ['tag']);
    $out .= qq{>};
    $out .= $rendered;
    $out .= qq{\n</$tag>};
    return $out;
}

sub wrapper_fieldset {
    my ( $self, $rargs, $rendered ) = @_;

    my $id = $rargs->{id};
    my $label = $self->localize($rargs->{label});
    my $out = qq{\n<fieldset id="$id"><legend class="label">$label</legend>};
    $out .= $rendered;
    $out .= qq{\n</fieldset>};
    return $out;
}

1;
