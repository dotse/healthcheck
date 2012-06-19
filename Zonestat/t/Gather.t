use Test::More;
use lib 't/lib';
# use MockBootstrap 'Gather';
use MockResolver 'Gather';

BEGIN { use_ok( 'Zonestat' ) }

#########################

my $p = Zonestat->new('examples/config')->gather;
ok( defined( $p ) );
ok( ref( $p ) eq 'Zonestat::Gather' );

is($p->cget(qw[couchdb url]), 'http://127.0.0.1:5984/');

is_deeply([$p->get_from_queue()], [], 'Queue is empty.');

ok($p->put_in_queue(
        {domain => 'foo.bar', priority => 2},
        {domain => 'example.org', priority => 1},
        {domain => 'gazonk.baz', priority  => 3}
        ));

my @qitems = $p->get_from_queue;

my $di = $p->set_active($qitems[0]->{_id}, 4711);
is($di->data->{tester_pid}, 4711, 'Tester PID correct on activated queue entry');
my $di2 = $p->reset_queue_entry($di->id);
is($di->id, $di2->id, 'Reset returns same database entry');
is($di2->data->{tester_pid}, undef, 'Reset works OK');

my $di3 = $p->set_active($qitems[1]->{_id}, 17);
ok($di3->data->{inprogress}, 'In progress flag set');
$p->reset_inprogress;
$di3->retrieve;
ok(!$di3->data->{inprogress}, 'In progress flag cleared');

my $di4 = $p->set_active($qitems[2]->{_id}, 17);
ok($p->requeue($di4->id), 'Requeue succeeded');
$di4->retrieve;
is($di4->data->{requeued}, 1, 'Requeue flag set to 1');
for(1..4) {
    $p->requeue($di4->id)
}
ok(!$p->requeue($di4->id), 'Sixth requeue failed as it should');

is_deeply([map {delete $_->{_id}; delete $_->{id}; delete $_->{_rev}; $_} @qitems], [
    {domain => 'example.org', priority => 1, inprogress => 1},
    {domain => 'foo.bar', priority => 2, inprogress => 1},
    {domain => 'gazonk.baz', priority  => 3, inprogress => 1},
    ], 'Expected queue items returned in expected order.');

ok($p->run_id >= 2, 'New run id OK');

my $zs = Zonestat->new('t/config/Config')->gather;

eval { $zs->enqueue_domainset};
like($@, qr/Unimplemented/, 'Unimplemented method dies.');

my $doc = $zs->single_domain('nic.se', {});
isa_ok($doc, 'CouchDB::Client::Doc');
ok($doc->data->{dnscheck}, 'Gathered document has content');

done_testing;
