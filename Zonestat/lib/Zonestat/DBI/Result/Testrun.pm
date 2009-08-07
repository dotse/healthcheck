package Zonestat::DBI::Result::Zone;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('testrun');
__PACKAGE__->add_columns(qw[id name ttl class type data]);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
    domainset => 'Zonestat::DBI::Result::Domainset',
    'set_id'
);
__PACKAGE__->has_many(tests => 'Zonestat::DBI::Result::Tests', 'run_id');

1;
