package Zonestat::DBI::Result::D2D_Topresolvers;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core Serialize::Storable]);
__PACKAGE__->table('d2d_topresolvers');
__PACKAGE__->add_columns(qw[id src qcount dnssec dns2db_id]);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(source => 'Zonestat::DBI::Result::Dns2db', 'dns2db_id');

1;
