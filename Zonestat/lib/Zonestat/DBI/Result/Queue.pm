package Zonestat::DBI::Result::Queue;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('queue');
__PACKAGE__->add_columns(qw[id domain priority inprogress tester_pid source_id source_data fake_parent_glue]);
__PACKAGE__->set_primary_key('id');

1;