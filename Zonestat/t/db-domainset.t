use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

my $zs = new_ok('Zonestat'  => ['t/config/Config']);

my $ds = $zs->domainset;
isa_ok($ds, 'Zonestat::DB::Domainset');

is($ds->all_sets, 1, 'One set');

my $test = $zs->domainset('test');
$test->add('nic.se', 'iis.se', 'example.org');

is_deeply([map {$_->name} $ds->all_sets], [qw(test testset)], 'One set');

is_deeply($test->all, ['example.org', 'iis.se', 'nic.se'], 'Right content.');

$test->remove('iis.se');
is_deeply($test->all, ['example.org', 'nic.se'], 'Can remove.');

$test->clear;
is($ds->all_sets, 1, 'One set again');

done_testing();