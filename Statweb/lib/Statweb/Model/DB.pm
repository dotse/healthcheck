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
        dbp => 'dbproxy',
        present => 'present',
        gather => 'gather',
    },
);

sub _build_zs {
    return Zonestat->new;
}

1;