package Zonestat::DBI::Result::Webserver;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('webserver');
__PACKAGE__->add_columns(qw[id raw type version created_at domain_id]);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(domain => 'Zonestat::DBI::Result::Domains', 'domain_id');

1;