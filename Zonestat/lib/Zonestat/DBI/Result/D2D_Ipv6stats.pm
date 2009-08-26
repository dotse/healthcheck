package Zonestat::DBI::Result::D2D_Ipv6stats;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('d2d_ipv6stats');
__PACKAGE__->add_columns(
    qw[id datum tid iptot ipv6total ipv6aaaa ipv6ns
      ipv6mx ipv6a ipv6soa ipv6ds ipv6a6 ipv4total
      ipv4aaaa ipv4ns ipv4mx ipv4a ipv4soa ipv4ds
      ipv4a6 dns2db_id]
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(source => 'Zonestat::DBI::Result::Dns2db', 'dns2db_id');

1;
