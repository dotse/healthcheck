#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Statweb' }

ok(request('/user/login')->is_success);
my $req = request('/');
ok($req->is_redirect, 'Request should redirect');
is($req->header('Location'), 'http://localhost/user/login');

done_testing;