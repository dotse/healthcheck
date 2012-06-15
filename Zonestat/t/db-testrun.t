use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

my $zs = new_ok('Zonestat'  => ['t/config/Config']);

my $tr = $zs->testrun(1);

isa_ok($tr, 'Zonestat::DB::Testrun');
ok($tr->fetch, 'Can fetch data.');

is($tr->test_count, 5, 'Expected number of tests in the run.');
is($tr->name, 'testset 2012-06-14 14:50', 'Name looks OK');
is($tr->domainset, 'testset', 'Domainset name OK');

is_deeply(
    [map {$_->{domain}} @{$tr->tests}],
    [qw(handelsbanken.se iis.se nic.se pts.se riksdagen.se)],
    'Names of tested domains look OK'
);

done_testing();