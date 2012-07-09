use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Statweb' }
BEGIN { use_ok 'Statweb::Controller::Testrun' }

ok( request('/testrun')->is_redirect, 'Request should redirect' );
done_testing();
