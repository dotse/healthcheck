package Zonestat::DBI::Result::Domains;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('domains');
__PACKAGE__->add_columns(qw[id domain last_test last_import]);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(tests => 'Zonestat::DBI::Result::Tests', {'foreign.domain' => 'self.domain'});

1;