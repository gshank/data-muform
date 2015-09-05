use strict;
use warnings;
use Test::More;
use Data::Dumper;

use_ok(' HTML::MuForm::Field' );

my $field = HTML::MuForm::Field->new( name => 'Foo' );

ok($field, 'field built');


{
    package Test::Form::Field::Text;
    use Moo;
    extends 'HTML::MuForm::Field';

    has 'cols' => ( is => 'rw' );
    has 'rows' => ( is => 'rw' );
}

$field = Test::Form::Field::Text->new( name => 'Bar' );
ok( $field, 'extended field built' );

done_testing;
