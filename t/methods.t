use strict;
use warnings;
use Test::More;

use Data::MuForm;

{
    package MyApp::Form::Test;
    use Moo;
    extends 'Data::MuForm';
    use Data::MuForm::Meta;
#   use Types::Standard ':all';

#   has '+name' => ( default => 'test' );
    has_field 'foo' => (
        methods => { build_id => sub { my $self = shift; return $self->name . "-id"; } }
    );
    has_field 'bar' => ( type => 'Select', label => 'BarNone' );;
    sub options_bar {
        my $self = shift;
        return $self->some_options;
    }
    sub some_options {
        (
           1 => 'apples',
           2 => 'oranges',
           3 => 'kiwi',
        )
    }

}

my @classes = MyApp::Form::Test->meta->linearized_isa;

my $form = MyApp::Form::Test->new;
ok( $form );
is( $form->field('foo')->id, 'foo-id', 'id is correct' );

$form->process( params => {} );

my $options = $form->field('bar')->options;

is_deeply( $options, [ { value => 1 => label => 'apples', order => 0 }, { value => 2, label => 'oranges', order => 1 }, { value => 3, label => 'kiwi', order => 2 } ], 'right options' );


done_testing;
