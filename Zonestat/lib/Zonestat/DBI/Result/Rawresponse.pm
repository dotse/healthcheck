package Zonestat::DBI::Result::Rawresponse;
use base 'DBIx::Class';
use Storable qw[nfreeze thaw];
use MIME::Base64;

__PACKAGE__->load_components(qw[Core Serialize::Storable]);
__PACKAGE__->table('rawresponses');
__PACKAGE__->add_columns(qw[id webserver_id raw_response]);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
    tests => 'Zonestat::DBI::Result::Webserver',
    'webserver_id'
);

__PACKAGE__->inflate_column(
    raw_response => {
        inflate => sub { thaw(decode_base64(shift)) },
        deflate => sub { encode_base64(nfreeze(shift)) },
    }
);

1;