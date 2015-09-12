use strict;
use warnings;
use Test::More;

use_ok( 'HTML::MuForm' );
use_ok( 'HTML::MuForm::Field' );
use_ok( 'HTML::MuForm::Fields' );
use_ok( 'HTML::MuForm::Field::Text' );
use_ok( 'HTML::MuForm::Field::Submit' );
use_ok( 'HTML::MuForm::Field::Checkbox' );
use_ok( 'HTML::MuForm::Field::Select' );
use_ok( 'HTML::MuForm::Field::Compound' );
use_ok( 'HTML::MuForm::Field::Integer' );
use_ok( 'HTML::MuForm::Field::PrimaryKey' );
use_ok( 'HTML::MuForm::Field::Repeatable' );

done_testing;
