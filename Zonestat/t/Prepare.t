# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Zonestat.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More qw[no_plan];    # tests => 1;
BEGIN { use_ok('Zonestat') }

#########################

my $p = Zonestat->new->prepare;
ok(defined($p));
ok(ref($p) eq 'Zonestat::Prepare');
