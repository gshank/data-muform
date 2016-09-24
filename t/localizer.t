#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use HTML::MuForm::Localizer;
use Test::More;

my $localizer = HTML::MuForm::Localizer->new(
  language => 'en',
);

ok( $localizer, 'created localizer' );

my $tr_str = $localizer->loc->__('error occurred');
is( $tr_str, 'error occurred', 'error_occurred' );

$tr_str = $localizer->loc->__x("'{field_label}' field is required", field_label => 'Some Field');
is( $tr_str, "'Some Field' field is required", 'required');

$tr_str = $localizer->loc->__x("{name} is nice", name => 'Joe Blow');
is( $tr_str, "Joe Blow is nice", 'message not in .po' );

done_testing;
