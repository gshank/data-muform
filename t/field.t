use strict;
use warnings;
use Test::More;
use Data::Dumper;

use_ok(' HTML::MooForm::Field' );

my $field = HTML::MooForm::Field->new( name => 'Foo' );

ok($field, 'field built');


{
    package Test::Form::Field::Text;
    use Moo;
    extends 'HTML::MooForm::Field';

    has 'cols' => ( is => 'rw' );
    has 'rows' => ( is => 'rw' );
}

$field = Test::Form::Field::Text->new( name => 'Bar' );
ok( $field, 'extended field built' );

done_testing;
