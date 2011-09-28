package Statweb::Model::DB;

use Moose;
use namespace::autoclean;

extends 'Catalyst::Model';

use Zonestat;
use Data::Dumper;

has 'zs' => (
    is => 'ro',
    isa => 'Zonestat',
    lazy_build => 1,
    handles => {
        db => 'db',
        present => 'present',
        gather => 'gather',
        dset => 'domainset',
        user => 'user',
        testrun => 'testrun',
        queue => 'queue',
        asdata => 'asdata',
        domainset => 'domainset',
    },
);

sub _build_zs {
    return Zonestat->new;
}

1;