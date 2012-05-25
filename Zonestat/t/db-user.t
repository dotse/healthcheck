use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

#########################

my $zs = new_ok('Zonestat'  => ['t/Config']);

my $u = $zs->user();

isa_ok($u, 'Zonestat::DB::User');

my $user = $u->create('testuser', 'testpassword', 'Test User', 'testuser@example.org');

is($user->{user}{name}, 'testuser', 'Created user has correct name.');
ok($user->{user}{salt}, 'Created user has a salt.');

my $loggedin = $u->login('testuser', 'testpassword');
isa_ok($loggedin, 'Zonestat::DB::User');

is_deeply($user, $loggedin, 'Logged in user is created user.');

done_testing();
