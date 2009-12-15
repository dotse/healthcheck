package Zonestat::DBI::Result::Mailserver;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core Serialize::Storable]);
__PACKAGE__->table('mailserver');
__PACKAGE__->add_columns(
    qw[id name starttls adsp run_id domain_id ip banner spf_spf spf_txt]);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
    domain => 'Zonestat::DBI::Result::Domains',
    'domain_id'
);
__PACKAGE__->belongs_to(testrun => 'Zonestat::DBI::Result::Testrun', 'run_id');

1;
