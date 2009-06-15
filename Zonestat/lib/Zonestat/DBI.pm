use warnings;
use strict;

package Zonestat::DBI;
use base 'Class::DBI';

our $connection_string;
our $db_user;
our $db_password;
our $dbh;

sub set_connection_data {
    my ($connection_string, $db_user, $db_password) = @_;
}

sub db_Main {
    if (defined($dbh) and $dbh->ping) {
        return $dbh;
    } else {
        $dbh = DBI->connect($connection_string, $db_user, $db_password, Zonestat::DBI->_default_attributes())
            or die $DBI::errstr;
    }
}

1;