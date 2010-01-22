package Zonestat::DBI::Result::PA_Row;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core Serialize::Storable]);
__PACKAGE__->table('pa_row');
__PACKAGE__->add_columns(
    qw[
      id
      pageanalysis_id
      url
      ip
      resource_type
      found_in
      depth
      start_order
      offset_time
      time_in_queue
      dns_lookup_time
      connect_time
      redirect_time
      first_byte
      download_time
      load_time
      status_code
      compressed
      compression_ratio
      compressed_file_size
      file_size
      request_headers
      response_headers
      error
      ]
);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to('pageanalysis', 'Zonestat::DBI::Result::Pageanalysis',
    'pageanalysis_id');

1;
