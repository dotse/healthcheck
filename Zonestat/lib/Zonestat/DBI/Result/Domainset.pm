package Zonestat::DBI::Result::Domainset;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('domainset');
__PACKAGE__->add_columns(qw[id name]);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(
    glue => 'Zonestat::DBI::Result::DomainSetGlue',
    'set_id'
);
__PACKAGE__->many_to_many(domains => 'glue', 'domain');

sub tests {
    my $self = shift;

    $self->glue->search_related('domain', {})->search_related('tests', {});
}

1;
