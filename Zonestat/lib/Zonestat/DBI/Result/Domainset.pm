package Zonestat::DBI::Result::Domainset;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core Serialize::Storable]);
__PACKAGE__->table('domainset');
__PACKAGE__->add_columns(qw[id dsgroup_id created_at]);
__PACKAGE__->add_columns(name => { accessor => '_name' });
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(
    glue => 'Zonestat::DBI::Result::DomainSetGlue',
    'set_id'
);
__PACKAGE__->has_many(testruns => 'Zonestat::DBI::Result::Testrun', 'set_id');

__PACKAGE__->many_to_many(domains => 'glue', 'domain');

__PACKAGE__->belongs_to('dsgroup', 'Zonestat::DBI::Result::Dsgroup',
    'dsgroup_id');

sub tests {
    my $self = shift;

    $self->glue->search_related('domain', {})->search_related('tests', {});
}

sub remove_domain {
    my ($self, $did) = @_;

    my $glue = $self->search_related('glue', { domain_id => $did })->first;
    my $domain = $glue->domain;
    $glue->delete;

    my $trs = $self->testruns;
    while (defined(my $tr = $trs->next)) {
        $tr->invalidate_cache;

        foreach my $relation ($tr->webservers_rs, $tr->mailservers_rs,
            $tr->servers_rs)
        {
            my $d = $relation->search({ domain_id => $did })->first;
            $d->delete if $d;
        }

        my $tests = $tr->search_related('tests', { domain => $domain->domain });
        while (defined(my $test = $tests->next)) {
            $test->delete;
        }
    }
}

sub name {
    my $self = shift;

    if (@_) {
        return $self->next::method(@_);
    }

    my $n = $self->_name;
    if ($n ne '') {
        return $n;
    } else {
        return $self->dsgroup->name;
    }
}

1;
