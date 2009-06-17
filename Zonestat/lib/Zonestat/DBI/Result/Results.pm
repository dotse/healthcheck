package Zonestat::DBI::Result::Results;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('results');
__PACKAGE__->add_columns(
    qw[id test_id line module_id parent_module_id timestamp level message
      arg0 arg1 arg2 arg3 arg4 arg5 arg6 arg7 arg8 arg9]
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(test => 'Zonestat::DBI::Result::Tests', 'test_id');
1;
