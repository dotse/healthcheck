use Test::More;
use lib 't/lib';

use MockWeb;

BEGIN{
    use_ok('Zonestat');
    use_ok('Zonestat::Collect::Webinfo');
}

my $zs = new_ok(Zonestat => ['t/config/Config']);

my ($name, $data) = Zonestat::Collect::Webinfo->collect('iis.se', $zs);

is($name, 'webinfo', 'Correct label');
is(scalar(keys(%$data)), 2, 'Right number of data sets');
is($data->{http}{https}, 0, 'https flag is off in http section');
is($data->{https}{https}, 1, 'https flag is on in https section');

my $h = $data->{http};

is($h->{charset}, 'utf-8', 'Right charset');
is($h->{content_type}, 'text/html', 'Right content-type');
is($h->{ending_tld}, 'se', 'Right TLD');
is($h->{ip}, '91.226.36.46', 'Right client IP');
is($h->{type}, 'Apache', 'Right server type');
is($h->{version}, '2.2.14', 'Right server version');

is($data->{https}{issuer}, 'Peer Certificate Issuer', 'Got the issuer string.');

done_testing;
