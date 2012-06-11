use Test::More;

use Zonestat::Util;
use Time::HiRes 'time';

my ($status, $stdout, $stderr) = run_external(10, q[/bin/echo Foo]);
ok($status);
is($stdout,"Foo\n");
is($stderr, undef);

my $before = time();
($status, $stdout, $stderr) = run_external(2, q[/bin/sleep 30]);
ok(!$status);
is($stdout, '');
is($stderr, '');
ok(time() - $before < 3);

my $dc = dnscheck();
$dc->smtp->test('something');

done_testing;