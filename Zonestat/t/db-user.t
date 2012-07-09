use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

#########################

my $zs = new_ok('Zonestat'  => ['t/config/Config']);

my $u = $zs->user();

isa_ok($u, 'Zonestat::DB::User');

my $user = $u->create('testuser', 'testpassword', 'Test User', 'testuser@example.org');

is($user->username, 'testuser', 'Created user has correct name.');
is($user->id, 'testuser', 'Created user has correct name.');
is($user->name, 'Test User');
is($user->email, 'testuser@example.org');
ok($user->{user}{salt}, 'Created user has a salt.');

my $loggedin = $u->login('testuser', 'testpassword');
isa_ok($loggedin, 'Zonestat::DB::User');
ok !$u->login('testuser', 'wrongpassword'), 'Not logged in with wrong password';

is_deeply($user, $loggedin, 'Logged in user is created user.');

$u->set_password('testuser', 'newpassword');
$loggedin = $u->login('testuser', 'newpassword');
is_deeply($user, $loggedin, 'Logged in with new password after changing it.');

my $nobody = $zs->user->login('nosuchuser', 'justsomething');
is($nobody, undef);

my $some = $zs->user->login('someuser', 'somepwd');
isa_ok($some, 'Zonestat::DB::User');

done_testing();
