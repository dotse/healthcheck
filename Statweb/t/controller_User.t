use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'Statweb' }
BEGIN { use_ok 'Statweb::Controller::User' }

ok(request('/user')->is_redirect, 'Request should redirect');

