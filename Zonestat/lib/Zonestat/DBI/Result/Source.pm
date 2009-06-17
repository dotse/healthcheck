package Zonestat::DBI::Result::Source;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('source');
__PACKAGE__->add_columns(qw[id name contact]);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(tests => 'Zonestat::DBI::Result::Tests', 'source_id');

1;