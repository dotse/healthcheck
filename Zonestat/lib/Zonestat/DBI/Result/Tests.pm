package Zonestat::DBI::Result::Tests;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('tests');
__PACKAGE__->add_columns(qw[id domain begin end source_id source_data count_critical count_error
    count_warning count_notice count_info]);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(results => 'Zonestat::DBI::Result::Results', 'test_id');
__PACKAGE__->belongs_to(source => 'Zonestat::DBI::Result::Source', 'source_id');
1;