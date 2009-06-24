package Zonestat::DBI::Result::User;
use base 'DBIx::Class';
use Digest::SHA1 'sha1_hex';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('user');
__PACKAGE__->add_columns(qw[id displayname username password email]);
__PACKAGE__->set_primary_key('id');

1;
