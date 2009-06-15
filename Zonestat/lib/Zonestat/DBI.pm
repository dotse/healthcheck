use warnings;
use strict;

package Zonestat::DBI;
use base 'Class::DBI';

our $connection_string;
our $db_user;
our $db_password;
our $dbh;

sub set_connection_data {
    ($connection_string, $db_user, $db_password) = @_;
}

sub db_Main {
    if (defined($dbh) and $dbh->ping) {
        return $dbh;
    } else {
        $dbh =
          DBI->connect($connection_string, $db_user, $db_password,
            { Zonestat::DBI->_default_attributes() })
          or die $DBI::errstr;
    }
}

package Zonestat::DBI::Result;
use base 'Zonestat::DBI';
Zonestat::DBI::Result->table('results');
Zonestat::DBI::Result->columns(
    All => qw[id test_id line module_id parent_module_id timestamp level message
      arg0 arg1 arg2 arg3 arg4 arg5 arg6 arg7 arg8 arg9]
);
Zonestat::DBI::Result->has_a(test_id => 'Zonestat::DBI::Test');

package Zonestat::DBI::Test;
use base 'Zonestat::DBI';

Zonestat::DBI::Test->table('tests');
Zonestat::DBI::Test->columns(
    All => qw[id domain begin end count_critical count_error count_warning
      count_notice count_info source_id source_data]
);
Zonestat::DBI::Test->has_many(results => 'Zonestat::DBI::Result');

1;
