use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Differences;

use_ok ( 'Data::MuForm::Localizer' );

my $class = 'Data::MuForm::Localizer';

my $msgstr = <<'EOT';
Content-Type: text/plain; charset=UTF-8
Plural-Forms: nplurals=2; plural=n != 1
EOT

my $extract_ref = $class->extract_header_msgstr($msgstr);

is($extract_ref->{charset}, 'UTF-8', 'charset ok');
is($extract_ref->{nplurals}, '2', 'nplurals ok');
is($extract_ref->{plural}, 'n != 1', 'plural ok');

eq_or_diff
    {
        map {
            $_ => $extract_ref->{plural_code}->($_);
        } qw( 0 1 2 )
    },
    {
        0 => 1,
        1 => 0,
        2 => 1,
    },
    'run plural_code';

throws_ok
    sub { $class->extract_header_msgstr },
    qr{ \A \QHeader is not defined\E \b }xms,
    'no header';

throws_ok
    sub { $class->extract_header_msgstr(<<'EOT') },
Content-Type: text/plain; charset=UTF-8
EOT
    qr{ \A \QPlural-Forms not found in header\E \b }xms,
    'no plural forms';

throws_ok
    sub { $class->extract_header_msgstr(<<'EOT') },
Plural-Forms: nplurals=2; plural=n != 1;
EOT
    qr{ \A \QContent-Type with charset not found in header\E \b }xms,
    'no charset';

done_testing;
