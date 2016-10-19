package Data::MuForm::Renderer::Base;
# ABSTRACT: Renderer

use Moo;
use List::Util ('any');
use Scalar::Util ('weaken');

=head1 NAME

Data::MuForm::Renderer::Base

=head1 DESCRIPTION

Base functionality for renderers, including rendering standard form controls.

Generally you should always create your own custom renderer class which inherits
from this one. In it you should set the various standard defaults for your
rendering, and override some of the methods, like 'render_errors'. You should
also create custom layouts using the layout sub naming convention so they can
be found.

There is a 'render_hook' which can be used to customize things like classes and
attributes. It is called on every 'render_field', 'render_element', 'render_errors',
and 'render_label' call. The hook can be used in the renderer or in the form class,
whichever is most appropriate.

This is Perl code, and can be customized however you want. This base renderer is
supplied as a library of useful routines. You could replace it entirely if you want,
as long you implement the methods that are used in the form and field classes.

As part of an attempt to separate the core code more from the rendering code, and
limit the explosion of various rendering attributes, the
rendering is always done using a 'render_args' hashref of the pieces of the form
and field that are needed for rendering.  Most of the rendering settings are set
as keys in the render_args hashref, with some exceptions. This means that you
can just start using a new render_args hashref key in your custom rendering code
without having to do anything special to get it there. You have to set it somewhere
of course, either in the field definition or passed in on the rendering calls.

For a particular field, the field class will supply a 'base_render_args', which is
merged with the 'render_args' from the field definition, which is merged with
the 'render_args' from the actual rendering call.

One of the main goals of this particular rendering iteration has been to make
it easy and seamless to limit rendering to only the field elements, so that all
of the complicated divs and classes that are necessary for recent 'responsive'
CSS frameworks can be done in the templates under the control of the frontend
programmers.

  [% form.field('foo').render_element({ class => 'mb10 tye', placeholder => 'Type...'}) %]

Or render the element, the errors and the labels, and do all of the other formatting
in the template:

   [% field = form.field('foo') %]
   <div class="sm tx10">
      [% field.render_label({ class="cxx" }) %]
      <div class="xxx">
        [% field.render_element({ class => 'mb10 tye', placeholder => 'Type...'}) %]
      </div>
      <div class="field-errors">[% field.render_errors %]</div>
   </div>

And yet another goal has been to make it possible to render a form automatically
and have it just work.

  [% form.render %]

=head1 Layouts

The 'standard' layouts are for all fields that don't have another layout type.
This includes text fields, selects, and textareas. Create a new layout with 'layout_<layout-name'.
Included layouts are 'lbl_ele_err' and 'no_label'. The default is 'lbl_ele_err', which renders
a label, the form control, and then error messages.

The 'radiogroup' layouts are for radiogroups, which is a 'Select' field layout type.
Create a new layout with 'rd_layout_<layout name>'.
Radiogroup option layouts are named 'rdgo_layout_<layout name>'. The provided layouts
are 'right_label' and 'left_label'.

Checkbox layout methods are named 'cb_layout_<layout name>'. The provided layouts are
'cbwrll' - checkbox wrapped, label left, 'cbwrlr' - checkbox wrapped, label right,
'cb2l' - checkbox with two labels, 'cbnowrll' - checkbox unwrapped, label left.

The checkbox group layouts are another 'Select' field layout type.
Checkbox group options layouts are named 'cbgo_layout_<layout name>'.

=head1 Form and Field methods

In the field:

    render (render_field, render_compound or render_repeatable in the renderer)
    render_element
    render_label
    render_errors

In the Select field:

    render_option (for select, radio group and checkbox group)

In the form:

    render (render_form in the renderer)
    render_start
    render_end
    render_errors (render_form_errors in the renderer)


=cut

has 'form' => ( is => 'ro', weak_ref => 1 );

has 'localizer' => ( is => 'ro' );

has 'default_standard_layout' => ( is => 'rw', default => 'lbl_ele_err' );

has 'default_cb_layout' => ( is => 'rw', default => 'cbwrlr' );

has 'default_rdgo_layout' => ( is => 'rw', default => 'labels_right' );

has 'default_cbgo_layout' => ( is => 'rw', default => 'labels_right' );

has 'default_field_wrapper' => ( is => 'rw', default => 'simple' );

has 'default_wrapper_tag' => ( is => 'rw', default => 'div' );

has 'default_error_tag' => ( is => 'rw', default => 'span' );

sub BUILD {
    my $self = shift;
    if ( $self->form ) {
        weaken($self->{localizer});
    }
}

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

  my $layout_type = $rargs->{layout_type};

  my $out;
  if ( $layout_type eq 'checkbox' ) {
     $out = $self->render_layout_checkbox($rargs);
  }
  elsif ( $layout_type eq 'checkboxgroup' ) {
     $out = $self->render_layout_checkboxgroup($rargs);
  }
  elsif ( $layout_type eq 'radiogroup' ) {
     $out = $self->render_layout_radiogroup($rargs);
  }
  elsif ( $layout_type eq 'element' ) { # submit, reset, hidden
     $out = $self->render_element($rargs);
  }
  elsif ( $layout_type eq 'list' ) { # list
     $out = $self->render_layout_list($rargs);
  }
  else {  # $layout_type eq 'standard'
     $out = $self->render_layout_standard($rargs);
  }

  return $self->wrap_field($rargs, $out);
}

sub wrap_field {
  my ( $self, $rargs, $out ) = @_;

  # wrap the field
  my $wrapper = $rargs->{wrapper} || $self->default_field_wrapper;
  return $out if $wrapper eq 'none';
  my $wrapper_meth = $self->can("wrapper_$wrapper") || die "wrapper method '$wrapper' not found";
  $out = $wrapper_meth->($self, $rargs, $out);
  return $out;
}

sub render_compound {
    my ( $self, $rargs, $fields ) = @_;

    my $out = '';
    foreach my $field ( @$fields ) {
        $out .= $field->render;
    }
    $out = $self->wrap_field($rargs, $out);
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

=head2 add_to_class

Utility class used to add to the 'class' key of an attribute hashref,
handling arrayref/not-arrayref, etc. Used to add 'error' and 'required'
classes.

=cut

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

Takes a hashref of key-value pairs to be rendered into HTML attributes.
Second param ($skip) is keys to skip in the hashref.

All 'values' are html filtered.

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
  my $size = $rargs->{size};

  # beginning of select
  my $out = qq{\n<select };
  $out .= qq{name="$name" };
  $out .= qq{id="$id" };
  $out .= qq{multiple="multiple" } if $rargs->{multiple};
  $out .= qq{size="$size" } if $size;
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
     $out .= $self->render_select_option($rargs, $option);
  }

  # end of select
  $out .= "\n</select>\n";
  return $out;
}

sub render_select_option {
    my ( $self, $rargs, $option ) = @_;

    my $label = $self->localize($option->{label});
    my $out = '';
    $out .= qq{\n<option };
    $out .= process_attrs($option, ['label', 'order']);
    $out .= qq{>$label</option>};
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
  my $error_tag = $rargs->{error_tag} || $self->default_error_tag;
  foreach my $error (@$errors) {
    $out .= qq{\n<$error_tag>$error</$error_tag>};
  }
   # TODO - should the errors be wrapped?
#  $out = qq{\n<div class="field-errors">$out</div>};
  return $out;
}

=comment
   <ul class="errors">     # error container
     <li>                # error message
       This field must contain an email address
     </li>
   </ul>
=cut

sub html_filter {
    my $string = shift;
    return '' if (!defined $string);
    $string =~ s/&/&amp;/g;
    $string =~ s/</&lt;/g;
    $string =~ s/>/&gt;/g;
    $string =~ s/"/&quot;/g;
    return $string;
}

sub render_option {
    my ( $self, $rargs, $option ) = @_;
    my $out = '';
    if ( $rargs->{layout_type} eq 'standard' ) {
        $out .= $self->render_select_option($rargs, $option);
    }
    elsif ( $rargs->{layout_type} eq 'checkboxgroup' ) {
        $out .= $self->render_checkbox_option($rargs, $option);
    }
    elsif ( $rargs->{layout_type} eq 'radiogroup' ) {
        $out .= $self->render_radio_option($rargs, $option);
    }
    return $out;
}

#==============================
#  Radio, Radiogroup
#==============================

sub render_layout_radiogroup {
  my ( $self, $rargs ) = @_;

  my $rdgo_layout = $rargs->{rdgo_layout} || $self->default_rdgo_layout;
  my $rdgo_layout_meth = $self->can("rdgo_layout_$rdgo_layout") or die "Radio layout '$rdgo_layout' not found";

  my $out = $self->render_label($rargs);
  # render options
  my $options = $rargs->{options};
  foreach my $option ( @$options ) {
    $out .= $rdgo_layout_meth->($self, $rargs, $option);
  }
  # TODO - is this the best place for error messages for radiogroups?
  $out .= $self->render_errors($rargs);
  return $out;
}

sub render_radio_option {
    my ( $self, $rargs, $option ) = @_;

    my $name = $rargs->{name};
    my $order = $option->{order};
    my $out = qq{<input type="radio" };
    $out .= qq{name="$name" };
    $out .= qq{id="$name$order" } unless $option->{id};
    $out .= process_attrs($option, ['label', 'order']);
    if ( $rargs->{fif} eq $option->{value} ) {
        $out .= qq{checked="checked" };
    }
    $out .= q{/>};
}

sub rdgo_layout_labels_left {
    my ( $self, $rargs, $option ) = @_;
    my $rd_element = $self->render_radio_option($rargs, $option);
    my $out = $self->render_radio_label($rargs, $option, '', $rd_element);
    return $out;
}

sub rdgo_layout_labels_right {
    my ( $self, $rargs, $option ) = @_;
    my $rd_element = $self->render_radio_option($rargs, $option);
    my $out = $self->render_radio_label($rargs, $option, $rd_element, '');
    return $out;
}

sub render_radio_label {
  my ( $self, $rargs, $option, $left_of_label, $right_of_label ) = @_;

  $right_of_label ||= '';
  $left_of_label ||= '';
  my $label = $self->localize($option->{label});

  my $attrs = { class => ['radio'] };
  $attrs->{for} = $option->{id} ? $option->{id} : $rargs->{name} . $option->{order};
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
  my $meth = $self->can("cb_layout_$cb_layout") || die "Checkbox layout '$cb_layout' not found";
  my $out = '';
  $out = $meth->($self, $rargs, $cb_element);
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

sub render_checkbox_option {
  my ( $self, $rargs, $option ) = @_;

  # prepare for checked attribute
  my $multiple = $rargs->{multiple};
  my $fif = $rargs->{fif} || [];
  my %fif_lookup;
  @fif_lookup{@$fif} = () if $multiple;


  my $name = $rargs->{name};
  my $value = $option->{value};
  my $order = $option->{order};
  my $out = qq{<input };
  $out .= qq{type="checkbox" };
  $out .= qq{name="$name" };
  $out .= qq{id="$name$order" } unless $option->{id};
  if ( defined $fif && ( ($multiple && exists $fif_lookup{$value}) || ( $fif eq $value ) ) ) {
      $out .= q{checked="checked" };
  }
  $out .= process_attrs($option, ['label', 'order']);
  $out .= "/>";
  return $out;
}

sub render_layout_checkboxgroup {
  my ( $self, $rargs ) = @_;

  my $out = $self->render_label($rargs);
  my $cbgo_layout = $rargs->{cbgo_layout} || $self->default_cbgo_layout;
  my $cbgo_layout_meth = $self->can("cbgo_layout_$cbgo_layout")
     || die "Checkbox group option layout '$cbgo_layout' not found";;
  # render options
  my $options = $rargs->{options};
  foreach my $option ( @$options ) {
      $out .= $cbgo_layout_meth->($self, $rargs, $option);
  }
  # TODO - is this the best place for error messages?
  $out .= $self->render_errors($rargs);
  return $out;
}

sub cbgo_layout_labels_right {
  my ( $self, $rargs, $option ) = @_;

  my $cb_element = $self->render_checkbox_option($rargs, $option);
  my $cb = $self->render_checkbox_label($rargs, $option, $cb_element, '');
  my $out .= $self->wrapper_div($rargs, $cb);
  return $out;
}

sub cbgo_layout_labels_left {
  my ( $self, $rargs, $option ) = @_;
  my $cb_element = $self->render_checkbox_option($rargs, $option);
  my $cb = $self->render_checkbox_label($rargs, $option, '', $cb_element);
  my $out .= $self->wrapper_div($rargs, $cb);
  return $out;
}

sub render_checkbox_label {
  my ( $self, $rargs, $option, $left_of_label, $right_of_label ) = @_;

  $right_of_label ||= '';
  $left_of_label ||= '';
  my $label = $self->localize($option->{label});

  my $attrs = { class => ['checkbox'] };
  $attrs->{for} = $option->{id} ? $option->{id} : $rargs->{name} . $option->{order};
  add_to_class( $attrs, $rargs->{checkbox_label_class} );

  my $out = qq{\n<label };
  $out.= process_attrs($attrs);
  $out .= q{>};
  $out .= qq{$left_of_label$label$right_of_label};
  $out .= qq{</label>};
}

=head2 cbwrll

Checkbox, wrapped, label left

   <label class="checkbox" for="option1"><input id="option1" name="option1" type="checkbox" value="1" /> Option1 </label>

=cut

sub cb_layout_cbwrll {
  my ( $self, $rargs, $cb_element ) = @_;

  my $out = $self->render_label($rargs, '', $cb_element);
  return $out

}

=head2 cbwrlr

Checkbox wrapped, label right

=cut

sub cb_layout_cbwrlr {
  my ( $self, $rargs, $cb_element ) = @_;

  my $out = $self->render_label($rargs, $cb_element, '' );
  return $out;
}

=head2 cbnowrll

Checkbox not wrapped, label left

=cut

sub cb_layout_cbnowrll {
  my ( $self, $rargs, $cb_element ) = @_;

  my $out = $self->render_label($rargs);
  $out .= $cb_element;
  return $out;
}

sub cb_layout_cb2l {
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

sub render_layout_standard {
  my ( $self, $rargs ) = @_;

  # render the field layout
  my $layout = $rargs->{layout} || $self->default_standard_layout;
  my $layout_meth = $self->can("layout_$layout");
  die "layout method '$layout' not found" unless $layout_meth;
  my $out = '';
  $out .= $layout_meth->($self, $rargs);
  return $out;
}

sub layout_lbl_ele_err {
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

# this is not orthogonal. get working and straighten up later
sub wrapper_div {
    my ( $self, $rargs, $rendered ) = @_;
    my $out = qq{\n<div>$rendered</div>};
    return $out;
}

sub render_layout_list {
    my ( $self, $rargs ) = @_;

    my $fif = $rargs->{fif} || [];
    my $size = $rargs->{size};
    $size ||= (scalar @{$fif} || 0) + ($rargs->{num_extra} || 0);
    $size ||= 2;
    my $out = $self->render_label($rargs);
    my $index = 0;
    while ( $size ) {
       my $value = shift @$fif;
       $value = defined $value ? $value : '';
       my $element = $self->render_input({%$rargs, fif => $value, id => $rargs->{id} . $index++ });
       $out .= $self->wrapper_div($rargs, $element);
       $size--;
    }
    return $out;
}

1;
