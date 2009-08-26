package Zonestat::DBI::Result::Dns2db;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('dns2db');
__PACKAGE__->add_columns(qw[id imported_at server]);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many(v6as => 'Zonestat::DBI::Result::D2D_V6as', 'dns2db_id');
__PACKAGE__->has_many(
    ipv6stats => 'Zonestat::DBI::Result::D2D_Ipv6stats',
    'dns2db_id'
);
__PACKAGE__->has_many(
    topresolvers => 'Zonestat::DBI::Result::D2D_Topresolvers',
    'dns2db_id'
);

1;
