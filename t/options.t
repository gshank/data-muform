use strict;
use warnings;
use Test::More;
use Data::Dumper;

use HTML::MuForm;

{
    package MyApp::Form::Test;
    use Moo;
    use HTML::MuForm::Meta;
    extends 'HTML::MuForm';

    has '+name' => ( default => 'test' );
    has_field 'foo';
    has_field 'bar' => ( type => 'Select', label => 'BarNone', options => [ 1 => 'One', 2 => 'Two' ] );
}

my $form = MyApp::Form::Test->new;
ok( $form );
is( $form->field('foo')->id, 'foo', 'id is correct' );
my $options = $form->field('bar')->options;
my $expected_options = [{ value => 1 => label => 'One' }, { value => 2, label => 'Two' }];
is_deeply( $options, $expected_options, 'got right options' );

{
    package MyApp::Form::Test2;
    use Moo;
    use HTML::MuForm::Meta;
    extends 'HTML::MuForm';

    has '+name' => ( default => 'test' );
    has_field 'foo';
    has_field 'bar' => ( type => 'Select' );
    sub options_bar {
        ( 1 => 'One', 2 => 'Two' )
    }
}


$form = MyApp::Form::Test2->new;
ok( $form, 'form built' );
is( $form->num_fields, 2, 'right number of fields' );
my $meta_fields = $form->meta_fields;
#diag(Dumper($meta_fields));
is( scalar @$meta_fields, 2, 'two meta fields' );
$form->process;
my $field = $form->field('bar');
ok( $field, 'got bar field' );
is_deeply( $field->options, $expected_options, 'got right options from form method' );

done_testing;
