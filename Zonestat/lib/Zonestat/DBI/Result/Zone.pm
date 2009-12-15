package Zonestat::DBI::Result::Zone;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core Serialize::Storable]);
__PACKAGE__->table('zone');
__PACKAGE__->add_columns(qw[id name ttl class type data]);
__PACKAGE__->set_primary_key('id');

1;
