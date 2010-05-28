package Zonestat::DBI::Result::Webserver;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core Serialize::Storable]);
__PACKAGE__->table('webserver');
__PACKAGE__->add_columns(
    qw[id raw_type type version created_at domain_id https issuer testrun_id ip url
      response_code content_type content_length charset redirect_count
      redirect_urls ending_tld robots_txt]
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(
    domain => 'Zonestat::DBI::Result::Domains',
    'domain_id'
);
__PACKAGE__->belongs_to(
    testrun => 'Zonestat::DBI::Result::Testrun',
    'testrun_id'
);

__PACKAGE__->has_one('pageanalysis', 'Zonestat::DBI::Result::Pageanalysis',
    'webserver_id');

__PACKAGE__->has_one('raw_response', 'Zonestat::DBI::Result::Rawresponse', 'webserver_id');

1;
