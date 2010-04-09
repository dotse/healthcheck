package Zonestat::DBI::Result::Dsgroup;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core Serialize::Storable]);
__PACKAGE__->table('dsgroup');
__PACKAGE__->add_columns(qw[id name]);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many('domainsets', 'Zonestat::DBI::Result::Domainset',
    'dsgroup_id');
__PACKAGE__->add_unique_constraint(['name']);

sub testruns {
    return
      shift->search_related('domainsets', {})->search_related('testruns', {});
}

sub active_set {
    return shift->search_related(
        'domainsets',
        {},
        {
            order_by => { -desc => 'id' },
            rows     => 1,
        }
    )->single;
}

1;
