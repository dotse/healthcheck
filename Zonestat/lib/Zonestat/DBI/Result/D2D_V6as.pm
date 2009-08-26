package Zonestat::DBI::Result::D2D_V6as;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('d2d_v6as');
__PACKAGE__->add_columns(
    qw[id foreign_id date count asname country description dns2db_id]);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(source => 'Zonestat::DBI::Result::Dns2db', 'dns2db_id');

1;
