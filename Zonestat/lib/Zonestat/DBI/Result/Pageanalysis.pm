package Zonestat::DBI::Result::Pageanalysis;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core Serialize::Storable]);
__PACKAGE__->table('pageanalysis');
__PACKAGE__->add_columns(
    qw[
      id
      webserver_id
      load_time
      requests
      rx_bytes
      compressed_resources
      average_compression
      effective_compression
      external_resources
      error
      ]
);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to('webserver', 'Zonestat::DBI::Result::Webserver',
    'webserver_id');
__PACKAGE__->has_many('result_row', 'Zonestat::DBI::Result::PA_Row',
    'pageanalysis_id');
1;
