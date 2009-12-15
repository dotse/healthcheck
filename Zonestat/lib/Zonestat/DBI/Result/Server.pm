package Zonestat::DBI::Result::Server;
use base 'DBIx::Class';

use Socket;

__PACKAGE__->load_components(qw[Core Serialize::Storable]);
__PACKAGE__->table('server');
__PACKAGE__->add_columns(
    qw[id kind country ip ipv6 asn city latitude longitude run_id domain_id created_at code]
);

# http://maps.google.com/maps?q=<latitude>+<longitude>
__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([qw[kind ip run_id domain_id]]);

__PACKAGE__->belongs_to(
    domain => 'Zonestat::DBI::Result::Domains',
    'domain_id'
);
__PACKAGE__->belongs_to(testrun => 'Zonestat::DBI::Result::Testrun', 'run_id');

sub reverse {
    my $self = shift;

    my ($name, $aliases, $addrtype, $length, @addrs) =
      gethostbyaddr(inet_aton($self->ip), AF_INET);

    if (defined($name)) {
        return $name;
    } else {
        return $self->ip;
    }
}

1;
