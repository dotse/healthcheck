package Zonestat::DBI::Result::Webserver;
use base 'DBIx::Class';
use Storable qw[nfreeze thaw];
use MIME::Base64;

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('webserver');
__PACKAGE__->add_columns(
    qw[id raw_type type version created_at domain_id https issuer testrun_id ip url
      raw_response response_code content_type content_length charset]
);
__PACKAGE__->inflate_column(
    raw_response => {
        inflate => sub { thaw(decode_base64(shift)) },
        deflate => sub { encode_base64(nfreeze(shift)) },
    }
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

1;
