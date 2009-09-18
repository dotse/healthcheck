package Zonestat::DBI::Result::Domains;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('domains');
__PACKAGE__->add_columns(qw[id domain last_test last_import]);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraint(domain => [qw(domain)]);

__PACKAGE__->has_many(
    tests => 'Zonestat::DBI::Result::Tests',
    { 'foreign.domain' => 'self.domain' }
);
__PACKAGE__->has_many(
    webservers => 'Zonestat::DBI::Result::Webserver',
    'domain_id'
);
__PACKAGE__->has_many(
    glue => 'Zonestat::DBI::Result::DomainSetGlue',
    'domain_id'
);
__PACKAGE__->many_to_many(sets => 'glue', 'domainset');
__PACKAGE__->has_many(servers => 'Zonestat::DBI::Result::Server', 'domain_id');

1;
