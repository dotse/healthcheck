package Zonestat::DBI::Result::Sslscan;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core Serialize::Storable]);
__PACKAGE__->table('sslscan');
__PACKAGE__->add_columns(qw[id xml port run_id domain_id]);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
    domain => 'Zonestat::DBI::Result::Domains',
    'domain_id'
);
__PACKAGE__->belongs_to(testrun => 'Zonestat::DBI::Result::Testrun', 'run_id');

1;
