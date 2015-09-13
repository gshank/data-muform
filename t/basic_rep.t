use strict;
use warnings;
use Test::More;

use_ok('HTML::MuForm::Field::Repeatable');

{
    package Test::Form;
    use Moo;
    use HTML::MuForm::Meta;
    extends 'HTML::MuForm';

    has_field 'my_name';
    has_field 'my_records' => ( type => 'Repeatable', num_when_empty => 2,);
    has_field 'my_records.one';
    has_field 'my_records.two';
}
my $form = Test::Form->new;
ok( $form, 'form built' );

is( $form->num_fields, 2, 'right number of form fields' );
my $rep_field = $form->field('my_records');
ok( $rep_field, 'we got the repeatable field' );

is( $rep_field->num_fields, 2, 'right number of repeatable fields' );
$DB::single=1;

my $rep_one = $rep_field->field('0');
ok( $rep_one, 'got first repeatable field' );

ok( $form->field('my_records.0.'), 'got field by another method');

is( $rep_one->num_fields, 2, 'first repeatable has 2 subfields' );

my $rep_two = $form->field('my_records.1');
ok( $rep_two, 'got second repeatable field' );
is( $rep_one->num_fields, 2, 'second repeatable has 2 subfields' );

my $expected_fif = {
    'my_name' => '',
    'my_records.0.one' => '',
    'my_records.0.two' => '',
    'my_records.1.one' => '',
    'my_records.1.two' => '',
};
my $fif = $form->fif;

is_deeply( $fif, $expected_fif, 'got right fif' );

done_testing;
