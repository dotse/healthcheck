use Test::More;
use lib 't/lib';

use MockWeb;

BEGIN{
    use_ok('Zonestat');
    use_ok('Zonestat::Collect::Webinfo');
}

my $zs = new_ok(Zonestat => ['t/config/Config']);

my ($name, $data) = Zonestat::Collect::Webinfo->collect('iis.se', $zs);

is($name, 'webinfo');
is(scalar(keys(%$data)), 2);
is($data->{http}{https}, 0);
is($data->{https}{https}, 1);

my $h = $data->{http};

is($h->{charset}, 'utf-8');
is($h->{content_type}, 'text/html');
is($h->{ending_tld}, 'se');
is($h->{ip}, '91.226.36.46');
is($h->{type}, 'Apache');
is($h->{version}, '2.2.14');
diag explain $data;

done_testing;
