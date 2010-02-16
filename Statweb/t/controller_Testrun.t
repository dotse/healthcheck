use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Statweb' }
BEGIN { use_ok 'Statweb::Controller::Testrun' }

ok( request('/testrun')->is_success, 'Request should succeed' );
done_testing();
