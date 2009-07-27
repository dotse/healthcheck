package Zonestat::DBI::Result::DomainSetGlue;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('domain_set_glue');
__PACKAGE__->add_columns(qw[id domain_id set_id]);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(
    domain => 'Zonestat::DBI::Result::Domains',
    'domain_id'
);
__PACKAGE__->belongs_to(
    domainset => 'Zonestat::DBI::Result::Domainset',
    'set_id'
);

1;
