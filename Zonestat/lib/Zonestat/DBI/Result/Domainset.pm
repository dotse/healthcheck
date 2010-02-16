package Zonestat::DBI::Result::Domainset;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core Serialize::Storable]);
__PACKAGE__->table('domainset');
__PACKAGE__->add_columns(qw[id name]);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(
    glue => 'Zonestat::DBI::Result::DomainSetGlue',
    'set_id'
);
__PACKAGE__->has_many(testruns => 'Zonestat::DBI::Result::Testrun', 'set_id');

__PACKAGE__->many_to_many(domains => 'glue', 'domain');

sub tests {
    my $self = shift;

    $self->glue->search_related('domain', {})->search_related('tests', {});
}

sub remove_domain {
    my ($self, $did) = @_;

    my $glue = $self->search_related('glue', { domain_id => $did })->first;
    $glue->delete;

    my $trs = $self->testruns;
    while (defined(my $tr = $trs->next)) {
        foreach my $relation (
            $tr->tests_rs,       $tr->webservers_rs,
            $tr->mailservers_rs, $tr->servers_rs
          )
        {
            my $d = $relation->search({ domain_id => $did })->first;
            $d->delete if $d;
        }
    }
}

1;
