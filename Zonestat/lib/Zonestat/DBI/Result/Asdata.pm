package Zonestat::DBI::Result::Asdata;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('asdata');
__PACKAGE__->add_columns(qw[id asn asname descr]);
__PACKAGE__->set_primary_key('id');

1;
