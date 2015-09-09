use strict;
use warnings;
use Test::More;

use HTML::MuForm;

{
    package MyApp::Form::Test;
    use Moo;
    extends 'HTML::MuForm';
    use HTML::MuForm::Meta;
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

is_deeply( $options, [ { value => 1 => label => 'apples' }, { value => 2, label => 'oranges' }, { value => 3, label => 'kiwi' } ], 'right options' );


done_testing;
