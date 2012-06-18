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
is(scalar(@{$test->all_docs}), 3, 'Right number of documents returned.');

$test->remove('iis.se');
is_deeply($test->all, ['example.org', 'nic.se'], 'Can remove.');

$test->clear;
is($ds->all_sets, 1, 'One set again');

my $ts = $zs->domainset('testset');
my @tss = $ts->testruns;
isa_ok($tss[0], 'Zonestat::DB::Testrun');

my $tr_id = $ts->enqueue;
ok( $tr_id > 1, 'Testrun ID larger than 1');

my ($rows, $next) = $ts->page(0,3);
is_deeply($rows, ['handelsbanken.se', 'iis.se'],'Page data OK');
is($next, 'nic.se', 'Next page key OK');

is($ts->prevkey($next,3), 'handelsbanken.se', 'Previous page key OK');

my $db = $zs->db('zonestat-queue');
foreach my $doc (@{$db->listDocs}) {
    $doc->retrieve;
    if($doc->data->{source_data} == $tr_id) {
        ok($doc->delete, $doc->id . " deleted");
    }
}

done_testing();