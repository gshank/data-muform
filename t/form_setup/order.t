use strict;
use warnings;
use Test::More;

{
    package MyApp::Form::Test;
    use Moo;
    use Data::MuForm::Meta;
    extends 'Data::MuForm';

    has_field 'fee';
    has_field 'fie';
    has_field 'foo' => ( order => 5 );
    has_field 'bar' => ( order => 99 );
    has_field 'mix';
    has_field 'max' => ( order => 35 );

}

my $form = MyApp::Form::Test->new;
ok( $form );
is( $form->field('fee')->order, 5, 'first field' );
is( $form->field('fie')->order, 10, 'second field' );
is( $form->field('foo')->order, 5, 'third field' );
is( $form->field('bar')->order, 99, 'fourth field' );
is( $form->field('mix')->order, 25, 'fifth field' );
is( $form->field('max')->order, 35, 'sixth field' );

my @names;
my @orders;
foreach my $field ( $form->all_sorted_fields ) {
    push @orders, $field->order;
    push @names, $field->name;
}

is_deeply( \@names, ['fee', 'foo', 'fie', 'mix', 'max', 'bar'], 'names in expected order' );
is_deeply( \@orders, [ 5, 5, 10, 25, 35, 99 ], 'order in expected order' );

{
    package MyApp::Form::Role::MyFields;
    use Moo::Role;
    use Data::MuForm::Meta;

    has_field 'r-one';
    has_field 'r-two';
    has_field 'r-three';
}

{
    package MyApp::Form::TestRole;
    use Moo;
    use Data::MuForm::Meta;
    extends 'Data::MuForm';

    with 'MyApp::Form::Role::MyFields';

    has_field 'f-one';
    has_field 'f-two';
    has_field 'f-three';
    has_field 'f-four';

}

$form = MyApp::Form::TestRole->new;
ok( $form, 'form built' );

is( $form->field('f-one')->order, 5, 'first field' );
is( $form->field('f-two')->order, 10, 'second field' );
is( $form->field('f-three')->order, 15, 'third field' );
is( $form->field('f-four')->order, 20, 'fourth field' );
is( $form->field('r-one')->order, 25, 'fifth field' );
is( $form->field('r-two')->order, 30, 'sixth field' );
is( $form->field('r-three')->order, 35, 'seventh field' );

done_testing;
