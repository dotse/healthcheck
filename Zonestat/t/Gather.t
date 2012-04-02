# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Zonestat.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More;
BEGIN { use_ok( 'Zonestat' => ['t/Config']) }

#########################

my $p = Zonestat->new->gather;
ok( defined( $p ) );
ok( ref( $p ) eq 'Zonestat::Gather' );

is($p->cget(qw[couchdb url]), 'http://127.0.0.1:5984/');

is_deeply([$p->get_from_queue()], [], 'Queue is empty.');

ok($p->put_in_queue(
        {domain => 'foo.bar', priority => 2},
        {domain => 'example.org', priority => 1},
        {domain => 'gazonk.baz', priority  => 3}
        ));

is_deeply([map {delete $_->{_id}; delete $_->{id}; delete $_->{_rev}; $_} $p->get_from_queue], [
    {domain => 'example.org', priority => 1, inprogress => 1},
    {domain => 'foo.bar', priority => 2, inprogress => 1},
    {domain => 'gazonk.baz', priority  => 3, inprogress => 1},
    ], 'Expected queue items returned in expected order.');

done_testing;