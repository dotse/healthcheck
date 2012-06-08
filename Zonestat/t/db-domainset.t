use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

my $zs = new_ok('Zonestat'  => ['t/config/Config']);

my $ds = $zs->domainset;
isa_ok($ds, 'Zonestat::DB::Domainset');

is($ds->all_sets, 0, 'No sets');

my $test = $zs->domainset('test');
$test->add('nic.se', 'iis.se', 'example.org');

is_deeply($ds->all_sets, $test, 'One set');

is_deeply($test->all, ['example.org', 'iis.se', 'nic.se'], 'Right content.');

$test->remove('iis.se');
is_deeply($test->all, ['example.org', 'nic.se'], 'Can remove.');

$test->clear;
is($ds->all_sets, 0, 'No sets');

done_testing();