use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'Statweb' }
BEGIN { use_ok 'Statweb::Controller::Testruns' }

ok(request('/testruns')->is_success, 'Request should succeed');

