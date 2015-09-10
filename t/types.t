use strict;
use warnings;
#use lib 't/lib';

use Test::More;
use Test::Fatal;

use HTML::MuForm::Types (':assert', ':all');

isa_ok( PositiveNum, 'Type::Tiny', 'PositiveNum' );

ok( assert_PositiveNum("5"), 'PositiveNum works (pass)' );
like( exception { assert_PositiveNum(-1) }, qr/positive number/, 'PositiveNum fails' );


done_testing;
