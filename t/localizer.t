#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Data::MuForm::Localizer;
use Test::More;

my $localizer = Data::MuForm::Localizer->new(
  language => 'en',
);

ok( $localizer, 'created localizer' );

# error_occurred
my $tr_str = $localizer->loc->__('error occurred');
is( $tr_str, 'error occurred', 'error_occurred' );

# required
$tr_str = $localizer->loc->__x("'{field_label}' field is required", field_label => 'Some Field');
is( $tr_str, "'Some Field' field is required", 'required');

# not in messages.po
$tr_str = $localizer->loc->__x("{name} is nice", name => 'Joe Blow');
is( $tr_str, "Joe Blow is nice", 'message not in .po' );

# range_incorrect
$tr_str = $localizer->loc->__x("Value must be between {low} and {high}", low => 5, high => 10);
is( $tr_str, "Value must be between 5 and 10", 'range_incorrect');

# range_too_high
$tr_str = $localizer->loc->__x("Value must be less than or equal to {high}", high => 20 );
is( $tr_str, "Value must be less than or equal to 20", 'range_too_high' );

done_testing;
